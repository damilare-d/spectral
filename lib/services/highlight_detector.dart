import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../ffi/analyzer_ffi.dart';
import '../ffi/whisper_ffi.dart';
import '../models/analysis_result.dart';
import '../models/content_type.dart';
import '../models/video_segment.dart';
import 'face_detection_service.dart';
import 'ffmpeg_service.dart';
import 'hook_detector.dart';
import 'whisper_model_service.dart';

// ── Progress events ───────────────────────────────────────────────────────────

sealed class AnalysisProgress {}

class AnalysisStage extends AnalysisProgress {
  final String label;
  final double fraction;
  final int stageIndex;
  final int totalStages;
  AnalysisStage(this.label, this.fraction, this.stageIndex, this.totalStages);
}

class AnalysisComplete extends AnalysisProgress {
  final AnalysisResult result;
  AnalysisComplete(this.result);
}

class AnalysisError extends AnalysisProgress {
  final String message;
  AnalysisError(this.message);
}

// ── Isolate entry points ──────────────────────────────────────────────────────

Future<({List<EnergyWindow> windows, List<int> onsetMs})> _energyIsolate(
    String pcmPath) async {
  final bytes = await File(pcmPath).readAsBytes();
  final pcmF32 = Float32List.view(bytes.buffer);
  return AnalyzerFFI.instance.analyzeAudio(pcmF32);
}

Future<List<WhisperSegment>> _whisperIsolate((String, String) args) async {
  final (modelPath, pcmPath) = args;
  final bytes = await File(pcmPath).readAsBytes();
  final pcmF32 = Float32List.view(bytes.buffer);
  WhisperFFI.instance.loadModel(modelPath);
  final segs = WhisperFFI.instance.transcribe(pcmF32);
  WhisperFFI.instance.unloadModel();
  return segs;
}

// ── Pipeline ──────────────────────────────────────────────────────────────────

class HighlightDetector {
  final FfmpegService _ffmpeg;
  final WhisperModelService _modelSvc;

  HighlightDetector({
    required FfmpegService ffmpegService,
    required WhisperModelService modelService,
  })  : _ffmpeg = ffmpegService,
        _modelSvc = modelService;

  static const int _segmentMs = 5000;
  static const int _strideMs  = 2500;

  Stream<AnalysisProgress> analyze(
    String videoPath, {
    bool runSpeech = false,
    ContentType? contentTypeOverride,
  }) async* {
    final total = runSpeech ? 5 : 4;

    try {
      yield AnalysisStage('Extracting audio…', 0.0, 0, total);
      final pcmPath = await _ffmpeg.extractAudio(videoPath);
      yield AnalysisStage('Extracting audio…', 1.0, 0, total);

      yield AnalysisStage('Analysing audio energy…', 0.0, 1, total);
      final audioResult = await Isolate.run(() => _energyIsolate(pcmPath));
      yield AnalysisStage('Analysing audio energy…', 1.0, 1, total);

      List<WhisperSegment> whisperSegs = [];
      if (runSpeech) {
        yield AnalysisStage('Transcribing speech…', 0.0, 2, total);
        final modelPath = await _modelSvc.ensureModel(onProgress: (p) {});
        whisperSegs = await Isolate.run(
            () => _whisperIsolate((modelPath, pcmPath)));
        yield AnalysisStage('Transcribing speech…', 1.0, 2, total);
      }

      final sceneStage = runSpeech ? 3 : 2;
      yield AnalysisStage('Detecting scene changes…', 0.0, sceneStage, total);
      final framePaths = await _ffmpeg.extractFrames(videoPath);
      final sceneDiffs = await _computeSceneDiffs(framePaths);
      yield AnalysisStage('Detecting scene changes…', 1.0, sceneStage, total);

      final faceStage = runSpeech ? 4 : 3;
      yield AnalysisStage('Detecting faces…', 0.0, faceStage, total);
      final faceSvc = FaceDetectionService();
      final faceScores = await faceSvc.scoreFrames(framePaths);
      await faceSvc.close();
      yield AnalysisStage('Detecting faces…', 1.0, faceStage, total);

      final pcmLength =
          await File(pcmPath).length().then((bytes) => bytes ~/ 4);
      final videoDurationMs = _estimateDuration(pcmLength);

      final (:segments, :contentType) = _buildSegments(
        videoDurationMs:    videoDurationMs,
        energyWindows:      audioResult.windows,
        onsetMs:            audioResult.onsetMs,
        whisperSegs:        whisperSegs,
        sceneDiffs:         sceneDiffs,
        faceScores:         faceScores,
        framePaths:         framePaths,
        contentTypeOverride: contentTypeOverride,
      );

      final transcript = whisperSegs.map((s) => s.text).join(' ');
      final topQuotes  = HookDetector.extractQuotes(whisperSegs);

      yield AnalysisComplete(AnalysisResult(
        segments:       segments,
        transcript:     transcript,
        videoDurationMs: videoDurationMs,
        videoPath:      videoPath,
        contentType:    contentType,
        topQuotes:      topQuotes,
      ));
    } catch (e, st) {
      yield AnalysisError('$e\n$st');
    }
  }

  // ── Scene diff ────────────────────────────────────────────────────────────

  Future<List<({int frameIndex, double diff})>> _computeSceneDiffs(
      List<String> framePaths) async {
    final diffs = <({int frameIndex, double diff})>[];
    Uint8List? prevRgba;
    int prevW = 0, prevH = 0;

    for (int i = 0; i < framePaths.length; i++) {
      final rgba = await _decodeFrameRgba(framePaths[i]);
      if (rgba == null) continue;
      const w = 160, h = 90;

      if (prevRgba != null) {
        final score =
            AnalyzerFFI.instance.frameDifference(prevRgba, rgba, prevW, prevH);
        diffs.add((frameIndex: i, diff: score));
      }
      prevRgba = rgba;
      prevW = w;
      prevH = h;
    }
    return diffs;
  }

  Future<Uint8List?> _decodeFrameRgba(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
          bytes, targetWidth: 160, targetHeight: 90);
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ── Segment scoring ───────────────────────────────────────────────────────

  /// Build, classify, score, NMS, and merge all candidate segments.
  ///
  /// Three-phase design:
  ///   1. Compute raw per-signal scores for every window.
  ///   2. Aggregate signals → classify content type (or use [contentTypeOverride]).
  ///   3. Set hookScore per window and recompute composite with type weights.
  ({List<VideoSegment> segments, ContentType contentType}) _buildSegments({
    required int videoDurationMs,
    required List<EnergyWindow> energyWindows,
    required List<int> onsetMs,
    required List<WhisperSegment> whisperSegs,
    required List<({int frameIndex, double diff})> sceneDiffs,
    required List<double> faceScores,
    required List<String> framePaths,
    ContentType? contentTypeOverride,
  }) {
    // ── Phase 1: raw signal scores, no composite yet ──────────────────────
    final segments = <VideoSegment>[];
    int start = 0;
    while (start < videoDurationMs) {
      final end = (start + _segmentMs).clamp(0, videoDurationMs);
      segments.add(VideoSegment(
        startMs:     start,
        endMs:       end,
        energyScore: _windowAvg(energyWindows, start, end, (w) => w.energy),
        onsetScore:  _onsetDensity(onsetMs, start, end),
        sceneScore:  _scenePeak(sceneDiffs, start, end),
        speechScore: _speechPresence(whisperSegs, start, end),
        faceScore:   _faceWindowScore(
            faceScores, framePaths.length, videoDurationMs, start, end),
      ));
      if (end >= videoDurationMs) break;
      start += _strideMs;
    }

    // ── Phase 2: classify content type ───────────────────────────────────
    final contentType =
        contentTypeOverride ?? _classifyContent(segments);
    final weights = ScoringWeights.presets[contentType]!;

    // ── Phase 3: hook score + composite with type-appropriate weights ─────
    for (final seg in segments) {
      seg.hookScore = HookDetector.windowHookScore(
          whisperSegs, seg.startMs, seg.endMs);
      seg.recomputeCompositeFromWeights(weights);
    }

    // ── NMS: keep highest-scoring non-overlapping windows ─────────────────
    segments.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    final kept = <VideoSegment>[];
    for (final seg in segments) {
      final overlaps =
          kept.any((k) => seg.startMs < k.endMs && seg.endMs > k.startMs);
      if (!overlaps) kept.add(seg);
    }

    return (segments: _mergeAdjacent(kept), contentType: contentType);
  }

  // ── Content-type classifier ───────────────────────────────────────────────

  ContentType _classifyContent(List<VideoSegment> segs) {
    if (segs.isEmpty) return ContentType.general;
    final n = segs.length.toDouble();

    double avgE = 0, avgO = 0, avgSc = 0, avgSp = 0, avgF = 0;
    for (final s in segs) {
      avgE  += s.energyScore;
      avgO  += s.onsetScore;
      avgSc += s.sceneScore;
      avgSp += s.speechScore;
      avgF  += s.faceScore;
    }
    avgE /= n; avgO /= n; avgSc /= n; avgSp /= n; avgF /= n;

    // Music/Concert: very high beat density
    if (avgO > 0.45 && avgE > 0.28) return ContentType.music;

    // Sports: high energy + beats + moderate scene changes
    if (avgE > 0.35 && avgO > 0.30 && avgSc > 0.18) return ContentType.sports;

    // Action/Movie: high scene changes + high energy
    if (avgSc > 0.28 && avgE > 0.32) return ContentType.action;

    // Podcast/Interview: high speech + face + low scene + low energy
    if (avgSp > 0.30 && avgF > 0.22 && avgSc < 0.20 && avgE < 0.28) {
      return ContentType.podcast;
    }

    // Tutorial/Talk: moderate speech, low visual activity
    if (avgSp > 0.25 && avgSc < 0.20 && avgE < 0.28) {
      return ContentType.tutorial;
    }

    return ContentType.general;
  }

  // ── Merge adjacent ────────────────────────────────────────────────────────

  List<VideoSegment> _mergeAdjacent(
    List<VideoSegment> segments, {
    int gapMs = 0,
    int maxMergeDurationMs = 30000,
  }) {
    if (segments.length <= 1) return segments;
    final sorted = List<VideoSegment>.from(segments)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    final merged = <VideoSegment>[];
    var current = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      final gap = next.startMs - current.endMs;
      final mergedDuration = next.endMs - current.startMs;

      if (gap <= gapMs && mergedDuration <= maxMergeDurationMs) {
        current = VideoSegment(
          startMs:     current.startMs,
          endMs:       next.endMs,
          energyScore: (current.energyScore + next.energyScore) / 2,
          onsetScore:  (current.onsetScore  + next.onsetScore)  / 2,
          sceneScore:  (current.sceneScore  + next.sceneScore)  / 2,
          speechScore: (current.speechScore + next.speechScore) / 2,
          faceScore:   current.faceScore > next.faceScore
              ? current.faceScore : next.faceScore,
          hookScore:   current.hookScore > next.hookScore
              ? current.hookScore : next.hookScore,
          compositeScore: current.compositeScore > next.compositeScore
              ? current.compositeScore : next.compositeScore,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  // ── Signal helpers ────────────────────────────────────────────────────────

  double _windowAvg(List<EnergyWindow> windows, int startMs, int endMs,
      double Function(EnergyWindow) value) {
    final inRange = windows
        .where((w) => w.startMs >= startMs && w.startMs < endMs)
        .toList();
    if (inRange.isEmpty) return 0.0;
    return inRange.map(value).reduce((a, b) => a + b) / inRange.length;
  }

  double _onsetDensity(List<int> onsetMs, int startMs, int endMs) {
    final count = onsetMs.where((t) => t >= startMs && t < endMs).length;
    final maxPerWindow = _segmentMs / 250;
    return (count / maxPerWindow).clamp(0.0, 1.0);
  }

  double _scenePeak(
      List<({int frameIndex, double diff})> diffs, int startMs, int endMs) {
    final inRange = diffs
        .where((d) {
          final ms = d.frameIndex * FfmpegService.frameIntervalMs;
          return ms >= startMs && ms < endMs;
        })
        .map((d) => d.diff)
        .toList();
    if (inRange.isEmpty) return 0.0;
    return inRange.reduce((a, b) => a > b ? a : b);
  }

  /// Raw speech presence score: confidence × density.
  /// Hook quality is applied separately in Phase 3.
  double _speechPresence(List<WhisperSegment> segs, int startMs, int endMs) {
    final inRange =
        segs.where((s) => s.t0Ms < endMs && s.t1Ms > startMs).toList();
    if (inRange.isEmpty) return 0.0;
    final avgProb =
        inRange.map((s) => s.prob).reduce((a, b) => a + b) / inRange.length;
    final density = (inRange.length / 10.0).clamp(0.0, 1.0);
    return (avgProb * 0.6 + density * 0.4).clamp(0.0, 1.0);
  }

  double _faceWindowScore(List<double> faceScores, int totalFrames,
      int videoDurationMs, int startMs, int endMs) {
    if (faceScores.isEmpty || totalFrames == 0 || videoDurationMs == 0) {
      return 0.0;
    }
    final startFrame = (startMs * totalFrames / videoDurationMs).floor();
    final endFrame =
        (endMs * totalFrames / videoDurationMs).ceil().clamp(0, totalFrames);
    if (startFrame >= endFrame) return 0.0;
    final slice = faceScores.sublist(startFrame, endFrame);
    return slice.reduce((a, b) => a > b ? a : b);
  }

  int _estimateDuration(int pcmSampleCount, {int sampleRate = 16000}) {
    return (pcmSampleCount * 1000 / sampleRate).round();
  }
}

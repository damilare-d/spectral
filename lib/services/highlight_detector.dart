import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../ffi/analyzer_ffi.dart';
import '../ffi/whisper_ffi.dart';
import '../models/analysis_result.dart';
import '../models/video_segment.dart';
import 'face_detection_service.dart';
import 'ffmpeg_service.dart';
import 'whisper_model_service.dart';

// ── Progress events ───────────────────────────────────────────────────────────

sealed class AnalysisProgress {}

class AnalysisStage extends AnalysisProgress {
  final String label;
  final double fraction; // 0–1 within this stage
  final int stageIndex;  // 0-based
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

// ── Isolate entry points (top-level so they are sendable) ────────────────────

/// Runs energy + onset analysis in a background isolate.
Future<({List<EnergyWindow> windows, List<int> onsetMs})> _energyIsolate(
    String pcmPath) async {
  final bytes = await File(pcmPath).readAsBytes();
  final pcmF32 = Float32List.view(bytes.buffer);
  return AnalyzerFFI.instance.analyzeAudio(pcmF32);
}

/// Runs Whisper transcription in a background isolate.
Future<List<WhisperSegment>> _whisperIsolate(
    (String, String) args) async {
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

  /// Run the full analysis pipeline, emitting [AnalysisProgress] events.
  ///
  /// [runSpeech]: when false, the Whisper stage is skipped entirely.
  /// Set to false for screen recordings or videos known to have no speech —
  /// Whisper on mobile CPU takes 3–10× real-time and can't be cancelled.
  Stream<AnalysisProgress> analyze(
    String videoPath, {
    bool runSpeech = false,
  }) async* {
    final total = runSpeech ? 5 : 4;

    try {
      // ── Stage 1: extract audio ────────────────────────────────────────────
      yield AnalysisStage('Extracting audio…', 0.0, 0, total);
      final pcmPath = await _ffmpeg.extractAudio(videoPath);
      yield AnalysisStage('Extracting audio…', 1.0, 0, total);

      // ── Stage 2: energy + onset (background isolate) ──────────────────────
      yield AnalysisStage('Analysing audio energy…', 0.0, 1, total);
      final audioResult = await Isolate.run(() => _energyIsolate(pcmPath));
      yield AnalysisStage('Analysing audio energy…', 1.0, 1, total);

      // ── Stage 3: Whisper transcription (optional) ─────────────────────────
      List<WhisperSegment> whisperSegs = [];
      if (runSpeech) {
        yield AnalysisStage('Transcribing speech…', 0.0, 2, total);
        final modelPath = await _modelSvc.ensureModel(
          onProgress: (p) {}, // model download handled in AnalysisViewModel
        );
        whisperSegs = await Isolate.run(
          () => _whisperIsolate((modelPath, pcmPath)),
        );
        yield AnalysisStage('Transcribing speech…', 1.0, 2, total);
      }

      // ── Stage 4: scene detection ──────────────────────────────────────────
      final sceneStage = runSpeech ? 3 : 2;
      yield AnalysisStage('Detecting scene changes…', 0.0, sceneStage, total);
      final framePaths = await _ffmpeg.extractFrames(videoPath);
      final sceneDiffs = await _computeSceneDiffs(framePaths);
      yield AnalysisStage('Detecting scene changes…', 1.0, sceneStage, total);

      // ── Stage 5: face detection ───────────────────────────────────────────
      // FaceDetectionService is created fresh each run because close() makes
      // the ML Kit detector permanently unusable.
      final faceStage = runSpeech ? 4 : 3;
      yield AnalysisStage('Detecting faces…', 0.0, faceStage, total);
      final faceSvc = FaceDetectionService();
      final faceScores = await faceSvc.scoreFrames(framePaths);
      await faceSvc.close();
      yield AnalysisStage('Detecting faces…', 1.0, faceStage, total);

      // ── Score segments ────────────────────────────────────────────────────
      final pcmLength = await File(pcmPath)
          .length()
          .then((bytes) => bytes ~/ 4); // float32 → sample count
      final videoDurationMs = _estimateDuration(pcmLength);
      final segments = _buildSegments(
        videoDurationMs:   videoDurationMs,
        energyWindows:     audioResult.windows,
        onsetMs:           audioResult.onsetMs,
        whisperSegs:       whisperSegs,
        sceneDiffs:        sceneDiffs,
        faceScores:        faceScores,
        framePaths:        framePaths,
      );

      final transcript = whisperSegs.map((s) => s.text).join(' ');
      yield AnalysisComplete(AnalysisResult(
        segments:        segments,
        transcript:      transcript,
        videoDurationMs: videoDurationMs,
        videoPath:       videoPath,
      ));
    } catch (e, st) {
      yield AnalysisError('$e\n$st');
    }
  }

  // ── Scene diff using native FFI ───────────────────────────────────────────

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
        final score = AnalyzerFFI.instance.frameDifference(prevRgba, rgba, prevW, prevH);
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
        bytes,
        targetWidth: 160,
        targetHeight: 90,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ── Segment scoring ───────────────────────────────────────────────────────

  List<VideoSegment> _buildSegments({
    required int videoDurationMs,
    required List<EnergyWindow> energyWindows,
    required List<int> onsetMs,
    required List<WhisperSegment> whisperSegs,
    required List<({int frameIndex, double diff})> sceneDiffs,
    required List<double> faceScores,
    required List<String> framePaths,
  }) {
    final segments = <VideoSegment>[];
    int start = 0;
    while (start < videoDurationMs) {
      final end = (start + _segmentMs).clamp(0, videoDurationMs);

      final energy = _windowAvg(energyWindows, start, end, (w) => w.energy);
      final onset  = _onsetDensity(onsetMs, start, end);
      final scene  = _scenePeak(sceneDiffs, start, end);
      final speech = _speechScore(whisperSegs, start, end);
      final face   = _faceWindowScore(faceScores, framePaths.length, videoDurationMs, start, end);

      final seg = VideoSegment(
        startMs:      start,
        endMs:        end,
        energyScore:  energy,
        onsetScore:   onset,
        sceneScore:   scene,
        speechScore:  speech,
        faceScore:    face,
      )..recomputeComposite();

      segments.add(seg);
      if (end >= videoDurationMs) break;
      start += _strideMs;
    }

    // Non-maximum suppression: drop overlapping segments, keep higher scorer
    segments.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    final kept = <VideoSegment>[];
    for (final seg in segments) {
      final overlaps = kept.any((k) =>
          seg.startMs < k.endMs && seg.endMs > k.startMs);
      if (!overlaps) kept.add(seg);
    }
    return kept;
  }

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
    final maxPerWindow = _segmentMs / 250; // one onset per hop
    return (count / maxPerWindow).clamp(0.0, 1.0);
  }

  double _scenePeak(List<({int frameIndex, double diff})> diffs, int startMs, int endMs) {
    final inRange = diffs
        .where((d) {
          final frameMs = d.frameIndex * 1000; // 1fps → ms
          return frameMs >= startMs && frameMs < endMs;
        })
        .map((d) => d.diff)
        .toList();
    if (inRange.isEmpty) return 0.0;
    return inRange.reduce((a, b) => a > b ? a : b);
  }

  double _speechScore(List<WhisperSegment> segs, int startMs, int endMs) {
    final inRange = segs.where((s) => s.t0Ms < endMs && s.t1Ms > startMs).toList();
    if (inRange.isEmpty) return 0.0;
    final avgProb = inRange.map((s) => s.prob).reduce((a, b) => a + b) / inRange.length;
    final density = (inRange.length / 10.0).clamp(0.0, 1.0);
    return (avgProb * 0.6 + density * 0.4).clamp(0.0, 1.0);
  }

  double _faceWindowScore(List<double> faceScores, int totalFrames,
      int videoDurationMs, int startMs, int endMs) {
    if (faceScores.isEmpty || totalFrames == 0 || videoDurationMs == 0) return 0.0;
    final startFrame = (startMs * totalFrames / videoDurationMs).floor();
    final endFrame   = (endMs   * totalFrames / videoDurationMs).ceil().clamp(0, totalFrames);
    if (startFrame >= endFrame) return 0.0;
    final slice = faceScores.sublist(startFrame, endFrame);
    return slice.reduce((a, b) => a > b ? a : b);
  }

  int _estimateDuration(int pcmSampleCount, {int sampleRate = 16000}) {
    return (pcmSampleCount * 1000 / sampleRate).round();
  }
}

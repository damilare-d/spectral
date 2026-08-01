import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/analysis_result.dart';
import '../../models/render_config.dart';
import '../../models/video_segment.dart';
import '../../services/render_service.dart';
import '../../services/ffmpeg_service.dart';

enum RenderPhase { config, rendering, done }

class ClipState {
  final VideoSegment segment;
  final int index;
  final int total;
  final double progress; // 0–1, approximate
  final String? outputPath;
  final String? error;

  const ClipState({
    required this.segment,
    required this.index,
    required this.total,
    this.progress = 0,
    this.outputPath,
    this.error,
  });

  bool get isDone => outputPath != null;
  bool get isFail => error != null;
  bool get isActive => !isDone && !isFail;

  ClipState copyWith({double? progress, String? outputPath, String? error}) =>
      ClipState(
        segment: segment,
        index: index,
        total: total,
        progress: progress ?? this.progress,
        outputPath: outputPath ?? this.outputPath,
        error: error ?? this.error,
      );
}

class RenderViewModel extends ChangeNotifier {
  final RenderService _renderer;
  final FfmpegService _ffmpeg;
  final RenderConfig config;

  final AnalysisResult result;
  final List<VideoSegment> segments;

  RenderPhase _phase = RenderPhase.config;
  List<ClipState> _clips = [];
  String? _reelPath; // set when batchMode = false

  RenderPhase get phase => _phase;
  List<ClipState> get clips => List.unmodifiable(_clips);
  String? get reelPath => _reelPath;

  int get doneCount => _clips.where((c) => c.isDone).length;
  int get failCount => _clips.where((c) => c.isFail).length;
  bool get allDone  => _clips.isNotEmpty && doneCount + failCount == _clips.length;

  RenderViewModel({
    required this.result,
    required this.segments,
    required this.config,
    required RenderService renderService,
    required FfmpegService ffmpegService,
  })  : _renderer = renderService,
        _ffmpeg = ffmpegService;

  // ── Start ─────────────────────────────────────────────────────────────────

  Future<void> startRender() async {
    _phase = RenderPhase.rendering;
    notifyListeners();

    if (config.batchMode) {
      await _runBatch();
    } else {
      await _runReel();
    }

    _phase = RenderPhase.done;
    notifyListeners();
  }

  Future<void> _runBatch() async {
    _clips = List.generate(
      segments.length,
      (i) => ClipState(segment: segments[i], index: i, total: segments.length),
    );
    notifyListeners();

    await for (final event
        in _renderer.batchRender(segments, result, config)) {
      _clips[event.index] = _clips[event.index].copyWith(
        progress: event.isDone ? 1.0 : 0.5,
        outputPath: event.outputPath,
        error: event.error,
      );
      notifyListeners();
    }
  }

  Future<void> _runReel() async {
    // Show a single "clip" representing the whole reel
    _clips = [
      ClipState(
        segment: segments.first,
        index: 0,
        total: 1,
        progress: 0,
      ),
    ];
    notifyListeners();

    try {
      final path = await _renderer.renderReel(segments, result, config);
      _reelPath = path;
      _clips[0] = _clips[0].copyWith(progress: 1.0, outputPath: path);
    } catch (e) {
      _clips[0] = _clips[0].copyWith(error: e.toString());
    }
    notifyListeners();
  }

  // ── Share / save ──────────────────────────────────────────────────────────

  Future<void> shareClip(ClipState clip) async {
    final path = clip.outputPath;
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: 'Made with Spectral');
  }

  Future<void> shareAll() async {
    final files = _clips
        .where((c) => c.outputPath != null)
        .map((c) => XFile(c.outputPath!))
        .toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files, text: 'Made with Spectral');
  }

  Future<String?> saveClip(ClipState clip) async {
    final path = clip.outputPath;
    if (path == null) return null;
    final name =
        'spectral_clip_${clip.index + 1}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    return _ffmpeg.saveToDownloads(path, name);
  }

  Future<void> saveAll() async {
    for (final c in _clips.where((c) => c.outputPath != null)) {
      await saveClip(c);
    }
  }

  String clipSizeMb(ClipState clip) {
    final path = clip.outputPath;
    if (path == null) return '?';
    return (File(path).lengthSync() / 1e6).toStringAsFixed(1);
  }
}

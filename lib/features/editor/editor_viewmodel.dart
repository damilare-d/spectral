import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/analysis_result.dart';
import '../../models/content_type.dart';
import '../../models/quote.dart';
import '../../models/video_segment.dart';

class EditorViewModel extends ChangeNotifier {
  late final AnalysisResult _result;
  late VideoPlayerController _videoCtrl;

  final List<VideoSegment> _selected = [];
  bool _videoReady = false;
  String? _videoError; // non-null when preview init fails
  VideoSegment? _activeSegment;
  String? _activeFilter; // null=all, ''=untagged, 'Action'=that tag

  bool get videoReady => _videoReady;
  String? get videoError => _videoError;
  List<VideoSegment> get selected => List.unmodifiable(_selected);
  VideoPlayerController get videoController => _videoCtrl;
  List<VideoSegment> get allSegments => _result.segments;
  int get videoDurationMs => _result.videoDurationMs;
  String get transcript => _result.transcript;
  String get videoPath => _result.videoPath;

  VideoSegment? get activeSegment => _activeSegment;
  bool get isPlaying => _videoReady && _videoCtrl.value.isPlaying;
  int get positionMs =>
      _videoReady ? _videoCtrl.value.position.inMilliseconds : 0;

  String? get activeFilter => _activeFilter;

  AnalysisResult get result => _result;
  ContentType get contentType => _result.contentType;
  List<Quote> get topQuotes => _result.topQuotes;

  /// Seek to an arbitrary position without changing the active segment.
  void seekToPosition(int ms) {
    _videoCtrl.seekTo(Duration(milliseconds: ms));
    notifyListeners();
  }

  Set<String> get allTags {
    final tags = <String>{};
    for (final s in _selected) {
      if (s.tag != null && s.tag!.isNotEmpty) tags.add(s.tag!);
    }
    return tags;
  }

  List<VideoSegment> get filtered {
    if (_activeFilter == null) return List.unmodifiable(_selected);
    if (_activeFilter!.isEmpty) {
      return List.unmodifiable(
        _selected.where((s) => s.tag == null || s.tag!.isEmpty).toList(),
      );
    }
    return List.unmodifiable(
      _selected.where((s) => s.tag == _activeFilter).toList(),
    );
  }

  void setTag(VideoSegment seg, String? newTag) {
    seg.tag = newTag;
    notifyListeners();
  }

  void setFilter(String? filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void init(AnalysisResult result) {
    _result = result;
    _selected.addAll(result.chronological);

    // contentUri is Android-only; use file() on every other platform.
    if (Platform.isAndroid && result.videoPath.startsWith('content://')) {
      _videoCtrl = VideoPlayerController.contentUri(
        Uri.parse(result.videoPath),
      );
    } else {
      _videoCtrl = VideoPlayerController.file(File(result.videoPath));
    }

    _initVideo();
  }

  Future<void> _initVideo() async {
    // On Windows, MKV / FLV / TS hang indefinitely in Media Foundation instead
    // of throwing — skip the video_player_windows path for those containers.
    final skipDirect =
        Platform.isWindows && _isUnsupportedOnWindowsMF(_result.videoPath);

    if (!skipDirect) {
      try {
        await _videoCtrl.initialize().timeout(const Duration(seconds: 15));
        _videoReady = true;
        _videoCtrl.addListener(_onVideoTick);
        notifyListeners();
        return;
      } catch (_) {}
    }

    if (!Platform.isWindows) {
      _videoError = 'Preview unavailable';
      notifyListeners();
      return;
    }

    // ── Windows fallback: remux → play, then encode → play ────────────────
    _videoError = 'Preparing preview…';
    notifyListeners();

    // Stage 1: fast stream-copy to MP4 (seconds; works for H.264/AAC MKV)
    String? previewPath;
    try {
      previewPath = await _remuxToMp4(_result.videoPath, encode: false);
      // ignore: avoid_print
      print('[Preview] stream-copy ok → $previewPath');
    } catch (e) {
      // ignore: avoid_print
      print('[Preview] stream-copy failed: $e');
    }

    if (previewPath != null && await _tryPlay(previewPath)) return;

    // Stage 2: encode to H.264 480p (slower; handles H.265/VP9/etc.)
    _videoError = 'Encoding preview…';
    notifyListeners();
    try {
      previewPath = await _remuxToMp4(_result.videoPath, encode: true);
      // ignore: avoid_print
      print('[Preview] encode ok → $previewPath');
    } catch (e) {
      // ignore: avoid_print
      print('[Preview] encode failed: $e');
      _videoError = 'Preview unavailable';
      notifyListeners();
      return;
    }

    if (!await _tryPlay(previewPath)) {
      _videoError = 'Preview unavailable';
      notifyListeners();
    }
  }

  /// Swap in a new controller pointing at [path] and try to initialize it.
  /// Returns true and marks video ready on success; returns false on failure.
  Future<bool> _tryPlay(String path) async {
    try {
      await _videoCtrl.dispose();
      _videoCtrl = VideoPlayerController.file(File(path));
      // ignore: avoid_print
      print('[Preview] initializing player: $path');
      await _videoCtrl.initialize().timeout(const Duration(seconds: 20));
      // ignore: avoid_print
      print('[Preview] initialized ok  size=${_videoCtrl.value.size}');
      _videoReady = true;
      _videoError = null;
      _videoCtrl.addListener(_onVideoTick);
      notifyListeners();
      return true;
    } catch (e, st) {
      // ignore: avoid_print
      print('[Preview] _tryPlay failed: $e\n$st');
      return false;
    }
  }

  /// Containers that Windows Media Foundation cannot play natively — they hang
  /// in initialize() instead of throwing, so we skip video_player_windows.
  static bool _isUnsupportedOnWindowsMF(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    return const {'mkv', 'flv', 'ts', 'webm', 'ogv'}.contains(ext);
  }

  /// Convert [videoPath] to a temp MP4. When [encode] is false, stream-copy
  /// is used (fast, preserves original codec). When [encode] is true, the
  /// video is transcoded to H.264 480p (slow but always WMF-compatible).
  Future<String> _remuxToMp4(String videoPath, {required bool encode}) async {
    final tmp = await getTemporaryDirectory();
    final workDir = Directory(p.join(tmp.path, 'spectral_work'));
    if (!workDir.existsSync()) workDir.createSync(recursive: true);

    final out     = p.join(workDir.path, encode ? 'preview_enc.mp4' : 'preview.mp4');
    final inPath  = videoPath.replaceAll('\\', '/');
    final outPath = out.replaceAll('\\', '/');

    // ignore: avoid_print
    print('[Preview] ${encode ? "encoding" : "remuxing"}: $inPath → $outPath');

    final args = encode
        ? [
            '-y', '-t', '60',
            '-i', inPath,
            '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '28',
            '-vf', 'scale=854:480:force_original_aspect_ratio=decrease,pad=854:480:(ow-iw)/2:(oh-ih)/2:black',
            '-c:a', 'aac', '-b:a', '96k',
            outPath,
          ]
        : [
            '-y', '-t', '300',
            '-i', inPath,
            '-map', '0:v:0?', '-map', '0:a:0?',
            '-c', 'copy',
            outPath,
          ];

    final result = await Process.run('ffmpeg', args);
    // ignore: avoid_print
    print('[Preview] ffmpeg exit=${result.exitCode}${result.exitCode != 0 ? "  stderr=${result.stderr}" : ""}');
    if (result.exitCode != 0) throw Exception(result.stderr);
    return out;
  }

  void _onVideoTick() {
    final seg = _activeSegment;
    if (seg != null && _videoCtrl.value.isPlaying) {
      final posMs = _videoCtrl.value.position.inMilliseconds;
      if (posMs >= seg.endMs) {
        _videoCtrl.pause();
        _videoCtrl.seekTo(Duration(milliseconds: seg.startMs));
      }
    }
    notifyListeners();
  }

  void seekTo(VideoSegment seg) {
    _activeSegment = seg;
    _videoCtrl.seekTo(Duration(milliseconds: seg.startMs));
    _videoCtrl.play();
    notifyListeners();
  }

  void togglePlayPause() {
    if (!_videoReady) return;
    if (_videoCtrl.value.isPlaying) {
      _videoCtrl.pause();
    } else {
      final seg = _activeSegment;
      if (seg != null) {
        final posMs = _videoCtrl.value.position.inMilliseconds;
        if (posMs >= seg.endMs || posMs < seg.startMs) {
          _videoCtrl.seekTo(Duration(milliseconds: seg.startMs));
        }
      }
      _videoCtrl.play();
    }
    notifyListeners();
  }

  void seekWithinActive(double fraction) {
    final seg = _activeSegment;
    if (seg == null) return;
    final ms = (seg.startMs + fraction * seg.durationMs).toInt();
    _videoCtrl.seekTo(Duration(milliseconds: ms));
  }

  void trimStart(VideoSegment seg, int deltaMs) {
    final idx = _selected.indexWhere((s) => s.startMs == seg.startMs);
    if (idx < 0) return;
    final newStart = (seg.startMs + deltaMs).clamp(0, seg.endMs - 1000);
    final updated = seg.copyWith(startMs: newStart);
    _selected[idx] = updated;
    if (_activeSegment?.startMs == seg.startMs) _activeSegment = updated;
    notifyListeners();
  }

  void trimEnd(VideoSegment seg, int deltaMs) {
    final idx = _selected.indexWhere((s) => s.startMs == seg.startMs);
    if (idx < 0) return;
    final newEnd = (seg.endMs + deltaMs).clamp(
      seg.startMs + 1000,
      _result.videoDurationMs,
    );
    final updated = seg.copyWith(endMs: newEnd);
    _selected[idx] = updated;
    if (_activeSegment?.startMs == seg.startMs) _activeSegment = updated;
    notifyListeners();
  }

  void removeSegment(VideoSegment seg) {
    if (_activeSegment?.startMs == seg.startMs) {
      _activeSegment = null;
      _videoCtrl.pause();
    }
    _selected.removeWhere((s) => s.startMs == seg.startMs);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _selected.removeAt(oldIndex);
    _selected.insert(newIndex, item);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_videoReady) _videoCtrl.removeListener(_onVideoTick);
    _videoCtrl.dispose();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../models/analysis_result.dart';
import '../../models/content_type.dart';
import '../../models/quote.dart';
import '../../models/video_segment.dart';

class EditorViewModel extends ChangeNotifier {
  late final AnalysisResult _result;
  late final VideoPlayerController _videoCtrl;

  final List<VideoSegment> _selected = [];
  bool _videoReady = false;
  VideoSegment? _activeSegment;
  String? _activeFilter; // null=all, ''=untagged, 'Action'=that tag

  bool get videoReady => _videoReady;
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
          _selected.where((s) => s.tag == null || s.tag!.isEmpty).toList());
    }
    return List.unmodifiable(
        _selected.where((s) => s.tag == _activeFilter).toList());
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

    // File picker on Android may return either a file path or a content:// URI.
    // Uri.file() breaks on content:// strings — parse generically instead.
    final videoUri = result.videoPath.startsWith('content://')
        ? Uri.parse(result.videoPath)
        : Uri.file(result.videoPath);

    _videoCtrl = VideoPlayerController.contentUri(videoUri)
      ..initialize().then((_) {
        _videoReady = true;
        _videoCtrl.addListener(_onVideoTick);
        notifyListeners();
      });
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
    final newEnd =
        (seg.endMs + deltaMs).clamp(seg.startMs + 1000, _result.videoDurationMs);
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

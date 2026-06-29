import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/video_segment.dart';
import '../../../services/ffmpeg_service.dart';

class ExportViewModel extends ChangeNotifier {
  final FfmpegService _ffmpeg;

  ExportViewModel({required FfmpegService ffmpegService})
      : _ffmpeg = ffmpegService;

  bool _isExporting = false;
  double _progress = 0.0;
  String? _outputPath;
  String? _error;
  bool _isDone = false;

  bool get isExporting => _isExporting;
  double get progress => _progress;
  String? get outputPath => _outputPath;
  String? get error => _error;
  bool get isDone => _isDone;

  Future<void> startExport(String videoPath, List<VideoSegment> segments) async {
    _isExporting = true;
    _progress = 0.0;
    notifyListeners();
    try {
      final path = await _ffmpeg.exportHighlights(
        videoPath,
        segments,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );
      _outputPath = path;
      _isDone = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> share() async {
    final path = _outputPath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path)],
      text: 'My highlight reel — made with Spectral',
    );
  }

  Future<String?> saveToDownloads() async {
    final path = _outputPath;
    if (path == null) return null;
    return _ffmpeg.saveToDownloads(
      path,
      'spectral_highlight_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  String get outputSizeMb {
    final path = _outputPath;
    if (path == null) return '?';
    return (File(path).lengthSync() / 1e6).toStringAsFixed(1);
  }
}

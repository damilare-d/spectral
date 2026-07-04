import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/video_segment.dart';

class FfmpegService {
  Future<Directory> get _tmpDir async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'spectral_work'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // Cap analysis at 90 minutes. Beyond this, the PCM + frame files become
  // too large for device memory and storage (a 2-hour BluRay would produce
  // 460 MB of PCM and 7,200 JPEG frames at 1fps with no cap).
  static const int _maxAnalysisSecs = 5400; // 90 min

  // One frame extracted per this many seconds. Exposed so HighlightDetector
  // can convert frameIndex → timestamp correctly.
  static const int secondsPerFrame = 5;
  static const int frameIntervalMs = secondsPerFrame * 1000;

  /// Extract float32 mono PCM at 16 kHz for Whisper + energy analysis.
  /// Returns the path to a raw .pcm file.
  Future<String> extractAudio(String videoPath) async {
    final dir = await _tmpDir;
    final outPath = p.join(dir.path, 'audio_16k.pcm');
    if (File(outPath).existsSync()) File(outPath).deleteSync();

    final input = await _toFfmpegInput(videoPath);
    final cmd =
        '-y -t $_maxAnalysisSecs -i "$input" -ac 1 -ar 16000 -f f32le "$outPath"';
    final session = await _runAsync(cmd);
    await _checkResult(session, 'extractAudio');
    return outPath;
  }

  /// Extract frames at 1 frame per [secondsPerFrame] seconds as JPEG thumbnails (160×90).
  /// Capped at [_maxAnalysisSecs] to prevent thousands of frames for long videos.
  /// Returns sorted list of frame file paths.
  Future<List<String>> extractFrames(String videoPath) async {
    final dir = await _tmpDir;
    final framesDir = Directory(p.join(dir.path, 'frames'));
    if (framesDir.existsSync()) framesDir.deleteSync(recursive: true);
    framesDir.createSync();

    final input = await _toFfmpegInput(videoPath);
    final pattern = p.join(framesDir.path, 'frame_%05d.jpg');
    final cmd =
        '-y -t $_maxAnalysisSecs -i "$input" '
        '-vf "fps=1/$secondsPerFrame,scale=160:90" -q:v 5 "$pattern"';
    final session = await _runAsync(cmd);
    await _checkResult(session, 'extractFrames');

    final files = framesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return files.map((f) => f.path).toList();
  }

  /// Stitch [segments] from [videoPath] into a single output MP4.
  Future<String> exportHighlights(
    String videoPath,
    List<VideoSegment> segments, {
    void Function(double)? onProgress,
  }) async {
    if (segments.isEmpty) throw ArgumentError('No segments to export');

    final dir = await _tmpDir;
    final outPath = p.join(dir.path, 'highlight_export.mp4');
    if (File(outPath).existsSync()) File(outPath).deleteSync();

    final input = await _toFfmpegInput(videoPath);
    final sb = StringBuffer('-y -i "$input" -filter_complex "');
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final startS = s.startMs / 1000.0;
      final endS   = s.endMs   / 1000.0;
      sb.write('[0:v]trim=start=$startS:end=$endS,setpts=PTS-STARTPTS[v$i];');
      sb.write('[0:a]atrim=start=$startS:end=$endS,asetpts=PTS-STARTPTS[a$i];');
    }

    final vLabels = List.generate(segments.length, (i) => '[v$i]').join();
    final aLabels = List.generate(segments.length, (i) => '[a$i]').join();
    sb.write(
        '${vLabels}concat=n=${segments.length}:v=1:a=0[outv];'
        '${aLabels}concat=n=${segments.length}:v=0:a=1[outa]" '
        '-map [outv] -map [outa] -c:v libx264 -c:a aac "$outPath"');

    final session = await _runAsync(sb.toString());
    await _checkResult(session, 'exportHighlights');
    return outPath;
  }

  /// Save an exported file to the Downloads directory.
  Future<String> saveToDownloads(String srcPath, String fileName) async {
    final downloads = Directory('/storage/emulated/0/Download');
    final dest = p.join(downloads.path, fileName);
    await File(srcPath).copy(dest);
    return dest;
  }

  /// Converts a raw path or content:// URI into a form FFmpeg can open.
  /// On Android, content:// URIs must go through the SAF pipe API —
  /// passing them directly gives "application context is not set".
  Future<String> _toFfmpegInput(String path) async {
    if (Platform.isAndroid && path.startsWith('content://')) {
      final saf = await FFmpegKitConfig.getSafParameterForRead(path);
      if (saf != null) return saf;
    }
    return path;
  }

  /// Wraps [executeAsync] in a Future so callers can simply await the result.
  /// Unlike [execute], this runs FFmpeg on a background thread and does NOT
  /// block Android's main thread (which would trigger a 5-second ANR).
  Future<FFmpegSession> _runAsync(String cmd) async {
    final completer = Completer<FFmpegSession>();
    await FFmpegKit.executeAsync(cmd, completer.complete);
    return completer.future;
  }

  Future<void> _checkResult(FFmpegSession session, String tag) async {
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogs();
      final log = logs.map((l) => l.getMessage()).join('\n');
      throw Exception('FFmpeg [$tag] failed:\n$log');
    }
  }
}

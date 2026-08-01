import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
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
    final outCmd = _posix(outPath);
    final cmd =
        '-y -t $_maxAnalysisSecs -i "$input" -ac 1 -ar 16000 -f f32le "$outCmd"';
    await _run(cmd, 'extractAudio');
    return outPath; // return native path for Dart file I/O
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
    final pattern = _posix(p.join(framesDir.path, 'frame_%05d.jpg'));
    final cmd =
        '-y -t $_maxAnalysisSecs -i "$input" '
        '-vf "fps=1/$secondsPerFrame,scale=160:90" -q:v 5 "$pattern"';
    await _run(cmd, 'extractFrames');

    final files =
        framesDir
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
    final outCmd = _posix(outPath);
    final sb = StringBuffer('-y -i "$input" -filter_complex "');
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final startS = s.startMs / 1000.0;
      final endS = s.endMs / 1000.0;
      sb.write('[0:v]trim=start=$startS:end=$endS,setpts=PTS-STARTPTS[v$i];');
      sb.write('[0:a]atrim=start=$startS:end=$endS,asetpts=PTS-STARTPTS[a$i];');
    }

    final vLabels = List.generate(segments.length, (i) => '[v$i]').join();
    final aLabels = List.generate(segments.length, (i) => '[a$i]').join();
    sb.write(
      '${vLabels}concat=n=${segments.length}:v=1:a=0[outv];'
      '${aLabels}concat=n=${segments.length}:v=0:a=1[outa]" '
      '-map [outv] -map [outa] -c:v libx264 -c:a aac "$outCmd"',
    );

    await _run(sb.toString(), 'exportHighlights');
    return outPath;
  }

  /// Save an exported file to the platform Downloads directory.
  Future<String> saveToDownloads(String srcPath, String fileName) async {
    Directory? downloads;
    if (Platform.isAndroid) {
      downloads = Directory('/storage/emulated/0/Download');
    } else {
      downloads = await getDownloadsDirectory();
    }

    if (downloads == null || !downloads.existsSync()) {
      downloads = await getApplicationDocumentsDirectory();
    }

    if (!downloads.existsSync()) downloads.createSync(recursive: true);

    final dest = p.join(downloads.path, fileName);
    await File(srcPath).copy(dest);
    return dest;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Dispatches to the correct FFmpeg backend for this platform.
  ///
  /// On Android/iOS: ffmpeg_kit_flutter_new (bundled library, no subprocess).
  /// On Windows: system ffmpeg.exe via Process.run, because the Windows plugin
  /// does not forward arguments to the native ffmpeg_execute() call — both
  /// executeAsync(String) and executeWithArgumentsAsync(List) drop args and
  /// FFmpeg runs with argc=1, printing only the usage banner.
  Future<void> _run(String cmd, String tag) async {
    // ignore: avoid_print
    print('[FFmpeg] cmd: $cmd');
    if (Platform.isWindows) {
      await _runProcess(cmd, tag);
    } else {
      await _runKit(cmd, tag);
    }
  }

  /// ffmpeg_kit_flutter_new path (Android / iOS).
  Future<void> _runKit(String cmd, String tag) async {
    final completer = Completer();
    await FFmpegKit.executeAsync(cmd, completer.complete);
    final session = await completer.future;
    final code = await session.getReturnCode();
    // ignore: avoid_print
    print('[FFmpeg] [$tag] return code: $code');
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogs();
      final errorLines = logs
          .map((l) => l.getMessage())
          .where(
            (m) =>
                m.isNotEmpty &&
                !m.startsWith('ffmpeg version') &&
                !m.startsWith('built with') &&
                !m.startsWith('configuration:') &&
                !m.startsWith('libav') &&
                !m.startsWith('Hyper fast Audio') &&
                !m.startsWith('usage:') &&
                !m.startsWith('Use -h'),
          )
          .join('\n');
      throw Exception('FFmpeg [$tag] failed (code: $code):\n$errorLines');
    }
  }

  /// System ffmpeg.exe path (Windows desktop).
  ///
  /// Requires FFmpeg in PATH. Install with:
  ///   winget install Gyan.FFmpeg
  ///   — or —
  ///   choco install ffmpeg
  Future<void> _runProcess(String cmd, String tag) async {
    final args = _parseArgs(cmd);
    // ignore: avoid_print
    print('[FFmpeg] [$tag] process args: $args');
    ProcessResult result;
    try {
      result = await Process.run('ffmpeg', args, runInShell: false);
    } on ProcessException catch (e) {
      throw Exception(
        'FFmpeg [$tag] failed: ffmpeg.exe not found in PATH.\n'
        'Install it with: winget install Gyan.FFmpeg\n'
        'Then restart the app.\n($e)',
      );
    }
    // ignore: avoid_print
    print('[FFmpeg] [$tag] exit code: ${result.exitCode}');
    if (result.exitCode != 0) {
      final stderr = result.stderr as String;
      final errorLines = stderr
          .split('\n')
          .where(
            (l) =>
                l.isNotEmpty &&
                !l.startsWith('ffmpeg version') &&
                !l.startsWith('built with') &&
                !l.startsWith('  configuration') &&
                !l.startsWith('  lib') &&
                !l.startsWith('Hyper fast') &&
                !l.startsWith('usage:') &&
                !l.startsWith('Use -h'),
          )
          .join('\n');
      throw Exception('FFmpeg [$tag] failed:\n$errorLines');
    }
  }

  /// Converts any path to forward-slash POSIX form for embedding in FFmpeg
  /// command strings. Both the MinGW32-based ffmpeg-kit build and the Windows
  /// system FFmpeg accept forward-slash paths. Use native OS paths for all
  /// Dart file I/O; only call this when building the command string.
  static String _posix(String path) => path.replaceAll('\\', '/');

  /// Converts a raw path or content:// URI into a form FFmpeg can open.
  Future<String> _toFfmpegInput(String path) async {
    if (Platform.isAndroid && path.startsWith('content://')) {
      final saf = await FFmpegKitConfig.getSafParameterForRead(path);
      if (saf != null) return saf;
    }
    return _posix(path);
  }

  /// Tokenises a command string respecting double-quoted tokens.
  /// Used by the Windows Process.run path to split the shared command string
  /// into a `List[String]` without shell-expanding quotes.
  static List<String> _parseArgs(String cmd) {
    final args = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < cmd.length; i++) {
      final ch = cmd[i];
      if (ch == '"') {
        inQuote = !inQuote;
      } else if (ch == ' ' && !inQuote) {
        if (buf.isNotEmpty) {
          args.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) args.add(buf.toString());
    return args;
  }
}

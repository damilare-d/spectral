import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/analysis_result.dart';
import '../models/render_config.dart';
import '../models/social_format.dart';
import '../models/video_segment.dart';
import 'subtitle_service.dart';

// ── Per-clip result ───────────────────────────────────────────────────────────

class ClipResult {
  final VideoSegment segment;
  final int index;
  final int total;
  final String? outputPath; // null while in progress
  final String? error;

  const ClipResult({
    required this.segment,
    required this.index,
    required this.total,
    this.outputPath,
    this.error,
  });

  bool get isDone  => outputPath != null;
  bool get isFail  => error != null;
}

// ── Render service ────────────────────────────────────────────────────────────

class RenderService {
  final SubtitleService _subs;
  RenderService({SubtitleService? subtitleService})
      : _subs = subtitleService ?? SubtitleService();

  /// Batch render — emits a [ClipResult] event for each clip as it completes.
  Stream<ClipResult> batchRender(
    List<VideoSegment> segments,
    AnalysisResult result,
    RenderConfig config,
  ) async* {
    final total = segments.length;
    for (int i = 0; i < total; i++) {
      final seg = segments[i];
      try {
        final outPath = await _renderOne(seg, i, result, config);
        yield ClipResult(
            segment: seg, index: i, total: total, outputPath: outPath);
      } catch (e) {
        yield ClipResult(
            segment: seg, index: i, total: total, error: e.toString());
      }
    }
  }

  /// Single joined reel — all segments concatenated then processed.
  Future<String> renderReel(
    List<VideoSegment> segments,
    AnalysisResult result,
    RenderConfig config,
  ) async {
    final dir = await _workDir();
    final outPath = p.join(dir.path, 'spectral_reel.mp4');
    final input = await _ffmpegInput(result.videoPath);
    final cmd = await _buildReelCmd(input, segments, result, config, outPath);
    await _run(cmd, 'renderReel');
    return outPath;
  }

  // ── Single clip ───────────────────────────────────────────────────────────

  Future<String> _renderOne(
    VideoSegment seg,
    int idx,
    AnalysisResult result,
    RenderConfig config,
  ) async {
    final dir  = await _workDir();
    final out  = p.join(dir.path, 'clip_${idx.toString().padLeft(3, '0')}.mp4');
    final inp  = await _ffmpegInput(result.videoPath);
    final cmd  = await _buildClipCmd(inp, seg, result, config, out);
    await _run(cmd, 'clip_$idx');
    return out;
  }

  // ── Filter graph builders ─────────────────────────────────────────────────

  Future<String> _buildClipCmd(
    String input,
    VideoSegment seg,
    AnalysisResult result,
    RenderConfig config,
    String outPath,
  ) async {
    final startS = seg.startMs / 1000.0;
    final durS   = seg.durationMs / 1000.0;
    final fmt    = config.format;

    // ── Input with fast seek ─────────────────────────────────────────────
    final sb = StringBuffer('-y -ss $startS -t $durS -i "$input"');

    // ── Music track input (if enabled) ──────────────────────────────────
    String? musicPath;
    if (config.music && config.musicAsset != null) {
      musicPath = await _assetPath(config.musicAsset!);
      sb.write(' -stream_loop -1 -i "$musicPath"');
    }

    // ── Subtitles input (if enabled) ────────────────────────────────────
    String? assPath;
    if (config.captions && result.whisperSegments.isNotEmpty) {
      assPath = await _subs.writeAssForSegment(
          seg, result.whisperSegments, config.captionStyle);
    }

    sb.write(' -filter_complex "');

    // ── Video chain ──────────────────────────────────────────────────────
    String vIn = '[0:v]';
    final vFilters = <String>[];

    // 1. Crop + scale for vertical formats
    if (config.verticalCrop && fmt.isVertical) {
      final xOffset = _cropOffset(seg, result, fmt);
      vFilters.add('crop=ih*9/16:ih:$xOffset:0');
      vFilters.add('scale=${fmt.width}:${fmt.height}:force_original_aspect_ratio=decrease');
      vFilters.add('pad=${fmt.width}:${fmt.height}:(ow-iw)/2:(oh-ih)/2:black');
    } else if (fmt.width > 0) {
      vFilters.add('scale=${fmt.width}:${fmt.height}:force_original_aspect_ratio=decrease');
      vFilters.add('pad=${fmt.width}:${fmt.height}:(ow-iw)/2:(oh-ih)/2:black');
    }

    // 2. Hook text overlay — first 2 seconds
    if (config.hookText && result.topQuotes.isNotEmpty) {
      final q = result.topQuotes.first;
      final qEnd = ((q.endMs - seg.startMs) / 1000.0).clamp(0.0, 2.5);
      final text = q.text.replaceAll("'", r"\'").replaceAll(':', r'\:');
      vFilters.add(
        "drawtext=text='$text'"
        ':fontsize=48:fontcolor=white:bordercolor=black:borderw=2'
        ':x=(w-text_w)/2:y=h*0.75'
        ":enable='between(t,0,$qEnd)'",
      );
    }

    // 3. Subtitle burn
    if (assPath != null) {
      final escaped = _posix(assPath).replaceAll(':', r'\:');
      vFilters.add("subtitles='$escaped'");
    }

    if (vFilters.isEmpty) {
      sb.write('${vIn}copy[outv]');
    } else {
      sb.write('$vIn${vFilters.join(',')}[outv]');
    }

    sb.write(';');

    // ── Audio chain ──────────────────────────────────────────────────────
    if (musicPath != null) {
      final duck = config.musicDuck;
      sb.write('[0:a]volume=1.0[origA];'
          '[1:a]volume=${duck.toStringAsFixed(2)}[musicA];'
          '[origA][musicA]amix=inputs=2:duration=first[outa]');
    } else {
      sb.write('[0:a]acopy[outa]');
    }

    sb.write('" -map [outv] -map [outa]');
    sb.write(' -c:v libx264 -preset fast -crf 23');
    sb.write(' -c:a aac -b:a 128k');
    sb.write(' -t $durS');
    sb.write(' "${_posix(outPath)}"');

    return sb.toString();
  }

  Future<String> _buildReelCmd(
    String input,
    List<VideoSegment> segments,
    AnalysisResult result,
    RenderConfig config,
    String outPath,
  ) async {
    final fmt = config.format;

    String? assPath;
    if (config.captions && result.whisperSegments.isNotEmpty) {
      final fakeSeg = VideoSegment(
        startMs: 0, endMs: result.videoDurationMs,
        energyScore: 0, onsetScore: 0, sceneScore: 0, speechScore: 0,
      );
      assPath = await _subs.writeAssForSegment(
          fakeSeg, result.whisperSegments, config.captionStyle);
    }

    final sb = StringBuffer('-y -i "$input"');

    final fc = StringBuffer('"');
    for (int i = 0; i < segments.length; i++) {
      final s     = segments[i];
      final start = s.startMs / 1000.0;
      final end   = s.endMs   / 1000.0;

      final vFilters = <String>[];
      if (config.verticalCrop && fmt.isVertical) {
        final xOffset = _cropOffset(s, result, fmt);
        vFilters.add('crop=ih*9/16:ih:$xOffset:0');
        vFilters.add('scale=${fmt.width}:${fmt.height}:force_original_aspect_ratio=decrease');
        vFilters.add('pad=${fmt.width}:${fmt.height}:(ow-iw)/2:(oh-ih)/2:black');
      }

      final vChain = vFilters.isEmpty ? '' : ',${vFilters.join(',')}';
      fc.write('[0:v]trim=start=$start:end=$end,setpts=PTS-STARTPTS$vChain[v$i];');
      fc.write('[0:a]atrim=start=$start:end=$end,asetpts=PTS-STARTPTS[a$i];');
    }

    final vLabels = List.generate(segments.length, (i) => '[v$i]').join();
    final aLabels = List.generate(segments.length, (i) => '[a$i]').join();
    final n = segments.length;

    fc.write('${vLabels}concat=n=$n:v=1:a=0[concatv];');
    fc.write('${aLabels}concat=n=$n:v=0:a=1[outa];');
    fc.write('[concatv]');
    if (assPath != null) {
      final escaped = _posix(assPath).replaceAll(':', r'\:');
      fc.write("subtitles='$escaped',");
    }
    fc.write('copy[outv]');
    fc.write('"');

    sb.write(' -filter_complex $fc');
    sb.write(' -map [outv] -map [outa]');
    sb.write(' -c:v libx264 -preset fast -crf 23');
    sb.write(' -c:a aac -b:a 128k');
    sb.write(' "${_posix(outPath)}"');

    return sb.toString();
  }

  // ── Crop offset helper ────────────────────────────────────────────────────

  int _cropOffset(VideoSegment seg, AnalysisResult result, SocialFormat fmt) {
    return 0; // centre crop — face-guided offset is a future enhancement
  }

  // ── FFmpeg dispatch ───────────────────────────────────────────────────────

  /// Dispatches to system ffmpeg.exe on Windows (ffmpeg_kit drops args there),
  /// or ffmpeg_kit on Android/iOS.
  Future<void> _run(String cmd, String tag) async {
    // ignore: avoid_print
    print('[Render] [$tag] cmd: $cmd');
    if (Platform.isWindows) {
      await _runProcess(cmd, tag);
    } else {
      await _runKit(cmd, tag);
    }
  }

  Future<void> _runProcess(String cmd, String tag) async {
    final args = _parseArgs(cmd);
    // ignore: avoid_print
    print('[Render] [$tag] args: $args');
    ProcessResult result;
    try {
      result = await Process.run('ffmpeg', args, runInShell: false);
    } on ProcessException catch (e) {
      throw Exception(
        'FFmpeg [$tag] failed: ffmpeg.exe not found in PATH.\n'
        'Install: winget install Gyan.FFmpeg\n($e)',
      );
    }
    // ignore: avoid_print
    print('[Render] [$tag] exit: ${result.exitCode}');
    if (result.exitCode != 0) {
      final stderr = result.stderr as String;
      final filtered = stderr
          .split('\n')
          .where((l) =>
              l.isNotEmpty &&
              !l.startsWith('ffmpeg version') &&
              !l.startsWith('built with') &&
              !l.startsWith('  configuration') &&
              !l.startsWith('  lib') &&
              !l.startsWith('Hyper fast') &&
              !l.startsWith('usage:') &&
              !l.startsWith('Use -h'))
          .join('\n');
      throw Exception('FFmpeg render [$tag] failed:\n$filtered');
    }
  }

  Future<void> _runKit(String cmd, String tag) async {
    final completer = Completer<void>();
    await FFmpegKit.executeAsync(cmd, (session) async {
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) {
        final logs = await session.getAllLogs();
        final log = logs.map((l) => l.getMessage()).join('\n');
        completer.completeError(Exception('FFmpeg render [$tag] failed:\n$log'));
      } else {
        completer.complete();
      }
    });
    return completer.future;
  }

  // ── Path helpers ──────────────────────────────────────────────────────────

  static String _posix(String path) => path.replaceAll('\\', '/');

  Future<String> _ffmpegInput(String path) async {
    if (Platform.isAndroid && path.startsWith('content://')) {
      final saf = await FFmpegKitConfig.getSafParameterForRead(path);
      if (saf != null) return saf;
    }
    return _posix(path);
  }

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

  Future<Directory> _workDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'spectral_render'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> _assetPath(String assetKey) async {
    return assetKey;
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ffi/whisper_ffi.dart';
import '../models/social_format.dart';
import '../models/video_segment.dart';

class SubtitleService {
  /// Write an ASS subtitle file for a single [seg] and return its path.
  ///
  /// Only segments that overlap [seg.startMs]–[seg.endMs] are included.
  /// Timestamps are re-zeroed so t=0 is the clip start.
  Future<String> writeAssForSegment(
    VideoSegment seg,
    List<WhisperSegment> whisper,
    CaptionStyle style,
  ) async {
    final inRange = whisper
        .where((w) => w.t1Ms > seg.startMs && w.t0Ms < seg.endMs)
        .toList();

    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'spectral_work'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final outPath = p.join(dir.path, 'subs_${seg.startMs}.ass');

    final buf = StringBuffer();
    buf.writeln(_assHeader(style));
    buf.writeln('[Events]');
    buf.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    if (style == CaptionStyle.wordPop) {
      _writeWordPop(buf, inRange, seg.startMs);
    } else {
      _writeBlock(buf, inRange, seg.startMs);
    }

    await File(outPath).writeAsString(buf.toString());
    return outPath;
  }

  // ── Block style — one sentence per card ─────────────────────────────────────

  void _writeBlock(
      StringBuffer buf, List<WhisperSegment> segs, int clipStartMs) {
    for (final w in segs) {
      final start = (w.t0Ms - clipStartMs).clamp(0, 999999999);
      final end   = (w.t1Ms - clipStartMs).clamp(0, 999999999);
      buf.writeln(
          'Dialogue: 0,${_ass(start)},${_ass(end)},Block,,0,0,0,,${_esc(w.text.trim())}');
    }
  }

  // ── Word-pop style — one word at a time, bold yellow ────────────────────────

  void _writeWordPop(
      StringBuffer buf, List<WhisperSegment> segs, int clipStartMs) {
    for (final w in segs) {
      final words = w.text.trim().split(RegExp(r'\s+'));
      if (words.isEmpty) continue;
      final totalMs = w.t1Ms - w.t0Ms;
      final msPerWord = totalMs / words.length;
      for (int i = 0; i < words.length; i++) {
        final start = ((w.t0Ms + i * msPerWord) - clipStartMs).clamp(0, 999999999).toInt();
        final end   = ((w.t0Ms + (i + 1) * msPerWord) - clipStartMs).clamp(0, 999999999).toInt();
        buf.writeln(
            'Dialogue: 0,${_ass(start)},${_ass(end)},WordPop,,0,0,0,,${_esc(words[i])}');
      }
    }
  }

  // ── ASS header ───────────────────────────────────────────────────────────────

  String _assHeader(CaptionStyle style) => '''
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 1

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
${style == CaptionStyle.block ? _blockStyle() : _wordPopStyle()}''';

  String _blockStyle() =>
      'Style: Block,Arial,52,&H00FFFFFF,&H000000FF,&H00000000,&HAA000000,-1,0,0,0,100,100,0,0,3,2,0,2,40,40,60,1';

  String _wordPopStyle() =>
      'Style: WordPop,Arial,72,&H00FFFF00,&H000000FF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,3,0,2,40,40,80,1';

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Format milliseconds as ASS timestamp  h:mm:ss.cs
  String _ass(int ms) {
    final h  = ms ~/ 3600000;
    final m  = (ms % 3600000) ~/ 60000;
    final s  = (ms % 60000) ~/ 1000;
    final cs = (ms % 1000) ~/ 10;
    return '$h:${_p(m)}:${_p(s)}.${_p(cs)}';
  }

  String _p(int v) => v.toString().padLeft(2, '0');

  String _esc(String t) => t.replaceAll('{', r'\{').replaceAll('}', r'\}');
}

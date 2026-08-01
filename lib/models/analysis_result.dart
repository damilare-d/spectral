import '../ffi/whisper_ffi.dart';
import 'content_type.dart';
import 'quote.dart';
import 'video_segment.dart';

class AnalysisResult {
  final List<VideoSegment> segments;
  final String transcript;
  final int videoDurationMs;
  final String videoPath;
  final ContentType contentType;
  final List<Quote> topQuotes;
  final List<WhisperSegment> whisperSegments;

  const AnalysisResult({
    required this.segments,
    required this.transcript,
    required this.videoDurationMs,
    required this.videoPath,
    this.contentType = ContentType.general,
    this.topQuotes = const [],
    this.whisperSegments = const [],
  });

  /// All segments sorted by time — no cap, editor shows everything.
  List<VideoSegment> get chronological {
    final sorted = List<VideoSegment>.from(segments)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return sorted;
  }
}

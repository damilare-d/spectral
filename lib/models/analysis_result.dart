import 'video_segment.dart';

class AnalysisResult {
  final List<VideoSegment> segments; // all candidates, sorted by compositeScore desc
  final String transcript;           // full transcript text joined
  final int videoDurationMs;
  final String videoPath;

  const AnalysisResult({
    required this.segments,
    required this.transcript,
    required this.videoDurationMs,
    required this.videoPath,
  });

  /// All segments sorted by time — no cap, editor shows everything.
  List<VideoSegment> get chronological {
    final sorted = List<VideoSegment>.from(segments)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return sorted;
  }
}

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

  List<VideoSegment> get topSegments {
    final sorted = List<VideoSegment>.from(segments)
      ..sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return sorted.take(5).toList();
  }

  List<VideoSegment> get chronological {
    final top = topSegments;
    top.sort((a, b) => a.startMs.compareTo(b.startMs));
    return top;
  }
}

class VideoSegment {
  final int startMs;
  final int endMs;
  final double energyScore;
  final double onsetScore;
  final double sceneScore;
  final double speechScore;
  double faceScore; // mutable — filled by ML Kit after construction
  double compositeScore;

  VideoSegment({
    required this.startMs,
    required this.endMs,
    required this.energyScore,
    required this.onsetScore,
    required this.sceneScore,
    required this.speechScore,
    this.faceScore = 0.0,
    this.compositeScore = 0.0,
  });

  int get durationMs => endMs - startMs;

  String get startLabel => _formatMs(startMs);
  String get endLabel   => _formatMs(endMs);

  static String _formatMs(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void recomputeComposite({
    double wEnergy = 0.25,
    double wOnset  = 0.20,
    double wScene  = 0.15,
    double wSpeech = 0.25,
    double wFace   = 0.15,
  }) {
    compositeScore =
        energyScore * wEnergy +
        onsetScore  * wOnset  +
        sceneScore  * wScene  +
        speechScore * wSpeech +
        faceScore   * wFace;
  }

  VideoSegment copyWith({int? startMs, int? endMs}) => VideoSegment(
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        energyScore: energyScore,
        onsetScore: onsetScore,
        sceneScore: sceneScore,
        speechScore: speechScore,
        faceScore: faceScore,
        compositeScore: compositeScore,
      );

  @override
  String toString() =>
      'VideoSegment($startLabel–$endLabel score=${compositeScore.toStringAsFixed(2)})';
}

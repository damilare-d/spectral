import 'content_type.dart';

class VideoSegment {
  final int startMs;
  final int endMs;
  final double energyScore;
  final double onsetScore;
  final double sceneScore;
  final double speechScore;
  double faceScore;     // filled by ML Kit after construction
  double hookScore;     // filled by HookDetector after Whisper
  double compositeScore;
  String? tag;          // user-assigned label

  VideoSegment({
    required this.startMs,
    required this.endMs,
    required this.energyScore,
    required this.onsetScore,
    required this.sceneScore,
    required this.speechScore,
    this.faceScore = 0.0,
    this.hookScore = 0.0,
    this.compositeScore = 0.0,
    this.tag,
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

  /// Recompute composite from per-signal scores.
  ///
  /// Hook score blends into the speech component (quality of language, not
  /// just presence). Degrades gracefully to pure speechScore when hookScore=0.
  void recomputeComposite({
    double wEnergy = 0.25,
    double wOnset  = 0.20,
    double wScene  = 0.15,
    double wSpeech = 0.25,
    double wFace   = 0.15,
  }) {
    final blendedSpeech = speechScore * 0.5 + hookScore * 0.5;
    compositeScore =
        energyScore   * wEnergy +
        onsetScore    * wOnset  +
        sceneScore    * wScene  +
        blendedSpeech * wSpeech +
        faceScore     * wFace;
  }

  /// Convenience overload that accepts a [ScoringWeights] preset directly.
  void recomputeCompositeFromWeights(ScoringWeights w) => recomputeComposite(
        wEnergy: w.wEnergy,
        wOnset:  w.wOnset,
        wScene:  w.wScene,
        wSpeech: w.wSpeech,
        wFace:   w.wFace,
      );

  VideoSegment copyWith({int? startMs, int? endMs}) => VideoSegment(
        startMs:       startMs ?? this.startMs,
        endMs:         endMs   ?? this.endMs,
        energyScore:   energyScore,
        onsetScore:    onsetScore,
        sceneScore:    sceneScore,
        speechScore:   speechScore,
        faceScore:     faceScore,
        hookScore:     hookScore,
        compositeScore: compositeScore,
        tag:           tag,
      );

  @override
  String toString() =>
      'VideoSegment($startLabel–$endLabel score=${compositeScore.toStringAsFixed(2)})';
}

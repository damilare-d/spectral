enum ContentType {
  general,
  podcast,
  action,
  music,
  tutorial,
  sports;

  String get label => switch (this) {
        ContentType.general  => 'General',
        ContentType.podcast  => 'Podcast / Interview',
        ContentType.action   => 'Action / Movie',
        ContentType.music    => 'Music / Concert',
        ContentType.tutorial => 'Tutorial / Talk',
        ContentType.sports   => 'Sports',
      };

  String get icon => switch (this) {
        ContentType.general  => '🎬',
        ContentType.podcast  => '🎙',
        ContentType.action   => '🎥',
        ContentType.music    => '🎵',
        ContentType.tutorial => '📖',
        ContentType.sports   => '⚽',
      };
}

class ScoringWeights {
  final double wEnergy;
  final double wOnset;
  final double wScene;
  final double wSpeech;
  final double wFace;

  const ScoringWeights({
    required this.wEnergy,
    required this.wOnset,
    required this.wScene,
    required this.wSpeech,
    required this.wFace,
  });

  // Weights sum to 1.0 in each preset.
  static const Map<ContentType, ScoringWeights> presets = {
    ContentType.general: ScoringWeights(
        wEnergy: 0.25, wOnset: 0.20, wScene: 0.15, wSpeech: 0.25, wFace: 0.15),
    ContentType.podcast: ScoringWeights(
        wEnergy: 0.08, wOnset: 0.05, wScene: 0.05, wSpeech: 0.50, wFace: 0.32),
    ContentType.action: ScoringWeights(
        wEnergy: 0.30, wOnset: 0.25, wScene: 0.25, wSpeech: 0.10, wFace: 0.10),
    ContentType.music: ScoringWeights(
        wEnergy: 0.22, wOnset: 0.42, wScene: 0.12, wSpeech: 0.12, wFace: 0.12),
    ContentType.tutorial: ScoringWeights(
        wEnergy: 0.10, wOnset: 0.08, wScene: 0.10, wSpeech: 0.45, wFace: 0.27),
    ContentType.sports: ScoringWeights(
        wEnergy: 0.30, wOnset: 0.22, wScene: 0.22, wSpeech: 0.14, wFace: 0.12),
  };
}

enum SocialFormat {
  tiktok,
  reels,
  shorts,
  twitter,
  landscape;

  String get label => switch (this) {
        SocialFormat.tiktok    => 'TikTok',
        SocialFormat.reels     => 'Reels',
        SocialFormat.shorts    => 'Shorts',
        SocialFormat.twitter   => 'Twitter / X',
        SocialFormat.landscape => 'Landscape',
      };

  String get icon => switch (this) {
        SocialFormat.tiktok    => '🎵',
        SocialFormat.reels     => '📸',
        SocialFormat.shorts    => '▶️',
        SocialFormat.twitter   => '🐦',
        SocialFormat.landscape => '🖥️',
      };

  int get width => switch (this) {
        SocialFormat.tiktok    => 1080,
        SocialFormat.reels     => 1080,
        SocialFormat.shorts    => 1080,
        SocialFormat.twitter   => 1280,
        SocialFormat.landscape => -2, // passthrough, keep original width
      };

  int get height => switch (this) {
        SocialFormat.tiktok    => 1920,
        SocialFormat.reels     => 1920,
        SocialFormat.shorts    => 1920,
        SocialFormat.twitter   => 720,
        SocialFormat.landscape => -2, // passthrough
      };

  int get maxDurationSec => switch (this) {
        SocialFormat.tiktok    => 60,
        SocialFormat.reels     => 60,
        SocialFormat.shorts    => 60,
        SocialFormat.twitter   => 140,
        SocialFormat.landscape => 600,
      };

  bool get isVertical => height > width && width > 0;
}

enum CaptionStyle {
  block,   // full sentence, white on dark bar
  wordPop; // one word at a time, yellow bold

  String get label => switch (this) {
        CaptionStyle.block   => 'Block',
        CaptionStyle.wordPop => 'Word pop',
      };
}

enum CropAnchor {
  face,
  center;

  String get label => switch (this) {
        CropAnchor.face   => 'Face (auto)',
        CropAnchor.center => 'Centre',
      };
}

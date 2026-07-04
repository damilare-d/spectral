import '../ffi/whisper_ffi.dart';
import '../models/quote.dart';

/// Pure-Dart static helpers for hook detection and quote extraction.
/// No network calls, no FFI — operates entirely on the Whisper transcript.
class HookDetector {
  HookDetector._();

  // ── Keyword lists ─────────────────────────────────────────────────────────

  static const _curiosity = [
    "you won't believe", "nobody tells you", "nobody told me",
    "the secret", "here's why", "this is why", "i wish i knew",
    "wait for it", "the real reason", "no one talks about",
    "this changes everything", "they don't want you",
  ];

  static const _questions = [
    "did you know", "what if", "have you ever", "why does",
    "how do you", "can you believe", "would you", "what would happen",
    "what happens when", "what would you do",
  ];

  static const _contrast = [
    "actually", "but wait", "turns out", "it turns out", "plot twist",
    "however", "instead", "the truth is", "in reality", "suddenly",
    "the problem is", "but here's the thing", "except", "until now",
  ];

  static const _emotion = [
    "insane", "crazy", "unbelievable", "incredible", "terrifying",
    "shocking", "amazing", "devastating", "hilarious", "mind-blowing",
    "life-changing", "heartbreaking", "breathtaking", "jaw-dropping",
    "surreal", "brutal", "wild",
  ];

  static const _cta = [
    "watch this", "look at this", "pay attention",
    "stop scrolling", "this is important", "i need you to see",
  ];

  static final _numberRegex = RegExp(
    r'\b\d[\d,]*\s*(%|k|m|b|million|billion|thousand|percent|'
    r'dollars|usd|seconds|minutes|hours|days|weeks|months|years|x\b|times)\b',
    caseSensitive: false,
  );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Hook score 0.0–1.0 for Whisper segments overlapping [startMs]–[endMs].
  static double windowHookScore(
    List<WhisperSegment> segs,
    int startMs,
    int endMs,
  ) {
    final inRange = segs.where((s) => s.t0Ms < endMs && s.t1Ms > startMs);
    if (inRange.isEmpty) return 0.0;
    final text = inRange.map((s) => s.text.toLowerCase()).join(' ');
    return (_rawPoints(text) / 8.0).clamp(0.0, 1.0);
  }

  /// Top [maxQuotes] standalone quotes from the full transcript.
  static List<Quote> extractQuotes(
    List<WhisperSegment> segs, {
    int maxQuotes = 5,
  }) {
    final scored = <Quote>[];
    for (final seg in segs) {
      final text = seg.text.trim();
      if (text.isEmpty) continue;

      final lower = text.toLowerCase();
      final score = seg.prob.clamp(0.0, 1.0) * 0.35 +
          _completeness(text) * 0.20 +
          _lengthScore(text) * 0.20 +
          (_rawPoints(lower) / 8.0).clamp(0.0, 1.0) * 0.25;

      if (score > 0.25) {
        scored.add(Quote(
          text: text,
          startMs: seg.t0Ms,
          endMs: seg.t1Ms,
          score: score,
        ));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxQuotes).toList();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static double _rawPoints(String lower) {
    double p = 0.0;
    for (final kw in _curiosity) { if (lower.contains(kw)) p += 3.0; }
    for (final kw in _questions) { if (lower.contains(kw)) p += 2.0; }
    for (final kw in _contrast)  { if (lower.contains(kw)) p += 2.0; }
    for (final kw in _emotion)   { if (lower.contains(kw)) p += 1.0; }
    for (final kw in _cta)       { if (lower.contains(kw)) p += 1.0; }
    if (_numberRegex.hasMatch(lower)) p += 2.0;
    return p;
  }

  static double _completeness(String text) =>
      (text.endsWith('.') || text.endsWith('!') || text.endsWith('?'))
          ? 1.0
          : 0.3;

  static double _lengthScore(String text) {
    final len = text.length;
    if (len < 10 || len > 220) return 0.0;
    if (len >= 20 && len <= 140) return 1.0;
    if (len < 20) return (len - 10) / 10.0;
    return (220 - len) / 80.0;
  }
}

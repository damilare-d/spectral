import 'package:flutter/material.dart';

import '../../../models/quote.dart';

class QuotesCard extends StatefulWidget {
  final List<Quote> quotes;
  final void Function(int ms) onSeek;

  const QuotesCard({super.key, required this.quotes, required this.onSeek});

  @override
  State<QuotesCard> createState() => _QuotesCardState();
}

class _QuotesCardState extends State<QuotesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.quotes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.deepPurple.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: Radius.circular(_expanded ? 0 : 10),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(
                      'Top quotes  (${widget.quotes.length})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(color: Colors.white10, height: 1),
              for (final q in widget.quotes)
                _QuoteRow(quote: q, onSeek: widget.onSeek),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  final Quote quote;
  final void Function(int ms) onSeek;

  const _QuoteRow({required this.quote, required this.onSeek});

  static String _formatMs(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSeek(quote.startMs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatMs(quote.startMs),
              style: const TextStyle(
                color: Colors.deepPurpleAccent,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '"${quote.text}"',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

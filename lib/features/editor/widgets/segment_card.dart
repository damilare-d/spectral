import 'package:flutter/material.dart';

import '../../../models/video_segment.dart';
import 'score_bar.dart';
import 'trim_button.dart';

class SegmentCard extends StatelessWidget {
  final VideoSegment seg;
  final int index;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final void Function(int deltaMs) onTrimStart;
  final void Function(int deltaMs) onTrimEnd;
  final VoidCallback onShowScores;
  final VoidCallback onSetTag;

  const SegmentCard({
    super.key,
    required this.seg,
    required this.index,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
    required this.onTrimStart,
    required this.onTrimEnd,
    required this.onShowScores,
    required this.onSetTag,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isActive ? const Color(0xFF2A1A4E) : const Color(0xFF1A1A2E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? const BorderSide(color: Colors.deepPurpleAccent, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onShowScores,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isActive
                        ? Colors.deepPurple
                        : Colors.deepPurple.withAlpha(80),
                    child: Text('$index',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${seg.startLabel} – ${seg.endLabel}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          '${(seg.durationMs / 1000).toStringAsFixed(1)}s  •  score ${seg.compositeScore.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onSetTag,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: seg.tag != null
                            ? Colors.deepPurple.withAlpha(180)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            seg.tag != null
                                ? Icons.label
                                : Icons.label_outline,
                            size: 11,
                            color: seg.tag != null
                                ? Colors.deepPurpleAccent
                                : Colors.white38,
                          ),
                          if (seg.tag != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              seg.tag!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              // ── Score bar ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: ScoreBar(score: seg.compositeScore),
              ),

              // ── Trim controls ─────────────────────────────────────────────
              Row(
                children: [
                  const Text('Start',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 4),
                  TrimButton(label: '−1s', onTap: () => onTrimStart(1000)),
                  TrimButton(label: '+1s', onTap: () => onTrimStart(-1000)),
                  const Spacer(),
                  const Text('End',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 4),
                  TrimButton(label: '−1s', onTap: () => onTrimEnd(-1000)),
                  TrimButton(label: '+1s', onTap: () => onTrimEnd(1000)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

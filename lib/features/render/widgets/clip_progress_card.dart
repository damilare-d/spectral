import 'package:flutter/material.dart';

import '../render_viewmodel.dart';

class ClipProgressCard extends StatelessWidget {
  final ClipState clip;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final String? sizeMb;

  const ClipProgressCard({
    super.key,
    required this.clip,
    required this.onShare,
    required this.onSave,
    this.sizeMb,
  });

  @override
  Widget build(BuildContext context) {
    final seg = clip.segment;
    final done = clip.isDone;
    final fail = clip.isFail;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fail
            ? Colors.red.withAlpha(20)
            : done
                ? const Color(0xFF0E1E0E)
                : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fail
              ? Colors.redAccent.withAlpha(60)
              : done
                  ? Colors.green.withAlpha(60)
                  : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon
              Icon(
                fail
                    ? Icons.error_outline
                    : done
                        ? Icons.check_circle_outline
                        : Icons.hourglass_empty,
                color: fail
                    ? Colors.redAccent
                    : done
                        ? Colors.greenAccent
                        : Colors.white38,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Clip ${clip.index + 1} of ${clip.total}  •  '
                '${seg.startLabel} – ${seg.endLabel}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (sizeMb != null)
                Text('$sizeMb MB',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipboardProgressBar(
            progress: clip.progress,
            done: done,
            fail: fail,
          ),

          if (fail) ...[
            const SizedBox(height: 6),
            Text(
              clip.error ?? 'Unknown error',
              style:
                  const TextStyle(color: Colors.redAccent, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (done) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: onShare,
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.download,
                  label: 'Save',
                  onTap: onSave,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ClipboardProgressBar extends StatelessWidget {
  final double progress;
  final bool done;
  final bool fail;

  const ClipboardProgressBar({
    super.key,
    required this.progress,
    required this.done,
    required this.fail,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: fail ? 1.0 : (done ? 1.0 : progress),
      backgroundColor: Colors.white10,
      color: fail
          ? Colors.redAccent
          : done
              ? Colors.greenAccent
              : Colors.deepPurpleAccent,
      minHeight: 4,
      borderRadius: BorderRadius.circular(2),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

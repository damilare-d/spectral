import 'package:flutter/material.dart';

import '../models/video_segment.dart';

class SegmentTimeline extends StatelessWidget {
  final List<VideoSegment> allSegments;
  final List<VideoSegment> selected;
  final int videoDurationMs;
  final int? currentPositionMs; // null = no playhead drawn
  final void Function(VideoSegment) onTap;

  const SegmentTimeline({
    super.key,
    required this.allSegments,
    required this.selected,
    required this.videoDurationMs,
    required this.onTap,
    this.currentPositionMs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (videoDurationMs <= 0) return;
            final tapMs = (details.localPosition.dx /
                    constraints.maxWidth *
                    videoDurationMs)
                .toInt();
            // Prefer a selected segment at the tap position; fall back to any.
            VideoSegment? hit;
            for (final s in selected) {
              if (tapMs >= s.startMs && tapMs <= s.endMs) {
                hit = s;
                break;
              }
            }
            hit ??= allSegments.firstWhere(
              (s) => tapMs >= s.startMs && tapMs <= s.endMs,
              orElse: () => allSegments.reduce((a, b) =>
                  (tapMs - a.startMs).abs() < (tapMs - b.startMs).abs()
                      ? a
                      : b),
            );
            onTap(hit);
          },
          child: CustomPaint(
            painter: _TimelinePainter(
              allSegments: allSegments,
              selected: selected,
              videoDurationMs: videoDurationMs,
              currentPositionMs: currentPositionMs,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final List<VideoSegment> allSegments;
  final List<VideoSegment> selected;
  final int videoDurationMs;
  final int? currentPositionMs;

  _TimelinePainter({
    required this.allSegments,
    required this.selected,
    required this.videoDurationMs,
    this.currentPositionMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (videoDurationMs <= 0) return;

    // Background track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // Segment bands
    for (final seg in allSegments) {
      final x1 = seg.startMs / videoDurationMs * size.width;
      final x2 = seg.endMs / videoDurationMs * size.width;
      final rect =
          Rect.fromLTWH(x1, 0, (x2 - x1).clamp(2, size.width), size.height);

      final isSelected = selected.any((s) => s.startMs == seg.startMs);
      final alpha = (seg.compositeScore * 200 + 55).clamp(55, 255).toInt();
      final color = isSelected
          ? Colors.deepPurpleAccent.withAlpha(alpha)
          : Colors.white.withAlpha((alpha * 0.4).toInt());

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color,
      );
    }

    // Playhead cursor (vertical line + small diamond cap)
    final posMs = currentPositionMs;
    if (posMs != null && posMs > 0) {
      final x = (posMs / videoDurationMs * size.width).clamp(0.0, size.width);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5,
      );
      final diamond = Path()
        ..moveTo(x, 0)
        ..lineTo(x - 4, -5)
        ..lineTo(x + 4, -5)
        ..close();
      canvas.drawPath(diamond, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.selected != selected ||
      old.allSegments != allSegments ||
      old.currentPositionMs != currentPositionMs;
}

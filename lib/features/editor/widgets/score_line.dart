import 'package:flutter/material.dart';

class ScoreLine extends StatelessWidget {
  final String label;
  final double score;
  final Color color;
  final bool bold;

  const ScoreLine(this.label, this.score, this.color,
      {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: bold ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.white12,
              color: color,
              minHeight: bold ? 6 : 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score.toStringAsFixed(2),
            style: TextStyle(
              color: bold ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

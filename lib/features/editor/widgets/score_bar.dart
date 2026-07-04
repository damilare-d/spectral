import 'package:flutter/material.dart';

class ScoreBar extends StatelessWidget {
  final double score;
  const ScoreBar({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.white12,
            color: Color.lerp(Colors.orange, Colors.greenAccent, score)!,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(score.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

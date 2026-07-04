import 'package:flutter/material.dart';

class TrimButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const TrimButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ),
    );
  }
}

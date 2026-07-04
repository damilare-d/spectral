import 'package:flutter/material.dart';

class OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final void Function(bool)? onChanged;
  final bool warningColor;

  const OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.warningColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: enabled
                  ? (warningColor ? Colors.amber : Colors.deepPurpleAccent)
                  : Colors.white24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: enabled ? Colors.white : Colors.white38,
                        fontSize: 13)),
                Text(sublabel,
                    style: TextStyle(
                        color: warningColor
                            ? Colors.amber.withAlpha(180)
                            : Colors.white24,
                        fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.deepPurpleAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

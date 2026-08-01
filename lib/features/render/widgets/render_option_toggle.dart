import 'package:flutter/material.dart';

class RenderOptionToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const RenderOptionToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              color: enabled ? Colors.white54 : Colors.white24, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: enabled ? Colors.white : Colors.white38,
                      fontSize: 14),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.deepPurpleAccent,
            activeTrackColor: Colors.deepPurple,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

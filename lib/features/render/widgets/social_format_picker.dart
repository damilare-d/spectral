import 'package:flutter/material.dart';

import '../../../models/social_format.dart';

class SocialFormatPicker extends StatelessWidget {
  final SocialFormat selected;
  final ValueChanged<SocialFormat> onChanged;

  const SocialFormatPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final fmt in SocialFormat.values)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onChanged(fmt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == fmt
                        ? Colors.deepPurple
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected == fmt
                          ? Colors.deepPurpleAccent
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmt.icon,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        fmt.label,
                        style: TextStyle(
                          color: selected == fmt
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 11,
                          fontWeight: selected == fmt
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        _dims(fmt),
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _dims(SocialFormat fmt) {
    if (fmt.width < 0) return 'original';
    return '${fmt.width}×${fmt.height}';
  }
}

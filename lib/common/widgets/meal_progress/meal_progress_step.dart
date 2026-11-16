import 'package:flutter/material.dart';

class MealProgressStep extends StatelessWidget {
  const MealProgressStep({
    super.key,
    required this.label,
    required this.complete,
    required this.current,
  });

  final String label;
  final bool complete;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF00A3FF);
    final inactiveColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final labelColor = current
        ? (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: complete || current ? activeColor : inactiveColor,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            if (complete) ...[
              const Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/status_timeline.dart';

/// A determinate timeline shared by activity and temporary-target cards.
class StatusTimeProgress extends StatelessWidget {
  const StatusTimeProgress({
    super.key,
    required this.startedAt,
    required this.endsAt,
    required this.now,
    required this.label,
    this.color,
  });

  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime now;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = StatusTimeline(
      start: startedAt,
      end: endsAt,
      now: now,
    ).progress;
    if (progress == null) return const SizedBox.shrink();

    final effectiveColor = color ??
        (isDark
            ? const Color(0xFF00A3FF)
            : Theme.of(context).colorScheme.primary);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 3.5,
            semanticsLabel: label,
            backgroundColor: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation(effectiveColor),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: effectiveColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

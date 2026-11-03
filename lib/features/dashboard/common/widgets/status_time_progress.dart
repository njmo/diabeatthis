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
  });

  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime now;
  final String label;

  @override
  Widget build(BuildContext context) {
    final progress = StatusTimeline(
      start: startedAt,
      end: endsAt,
      now: now,
    ).progress;
    if (progress == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
          semanticsLabel: label,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

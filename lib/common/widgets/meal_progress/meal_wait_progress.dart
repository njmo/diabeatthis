import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class MealWaitProgress extends StatelessWidget {
  const MealWaitProgress({
    super.key,
    required this.remaining,
    required this.total,
    this.waitingForExtendedCarbs = false,
  });

  final Duration remaining;
  final Duration total;
  final bool waitingForExtendedCarbs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSeconds = total.inSeconds > 0 ? total.inSeconds : 0;
    final seconds = remaining.inSeconds.clamp(0, totalSeconds);
    final progress = total.inSeconds <= 0
        ? 0.0
        : (seconds / total.inSeconds).clamp(0.0, 1.0);
    final minutes = (seconds / 60).ceil();
    final countdown =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final elapsed = remaining <= Duration.zero;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  elapsed
                      ? lang.mealProgressWaitElapsed
                      : lang.mealProgressWaitRemaining,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Text(countdown, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            borderRadius: BorderRadius.circular(5),
            semanticsLabel:
                '${elapsed ? lang.mealProgressWaitElapsed : lang.mealProgressWaitRemaining}, ${lang.durationMinutesShort(minutes)}',
          ),
          if (waitingForExtendedCarbs) ...[
            const SizedBox(height: 8),
            Text(lang.mealWaitPendingExtendedCarbs),
          ],
        ],
      ),
    );
  }
}

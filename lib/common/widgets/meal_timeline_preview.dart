import 'package:flutter/material.dart';

import '../l10n/language.dart';

class MealTimelinePreview extends StatelessWidget {
  const MealTimelinePreview({
    super.key,
    required this.startedAt,
    required this.endedAt,
    required this.insulinAt,
  });
  final DateTime startedAt;
  final DateTime endedAt;
  final DateTime insulinAt;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final events = [
      (
        label: context.lang.mealFlowInsulinTime,
        time: insulinAt,
        icon: Icons.medication_outlined,
      ),
      (
        label: context.lang.uiEatingStarted,
        time: startedAt,
        icon: Icons.restaurant_outlined,
      ),
      (
        label: context.lang.mealFlowEatingEnd,
        time: endedAt,
        icon: Icons.check_circle_outline,
      ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.lang.mealTimelineTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final event in events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      event.icon,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(event.label)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${localizations.formatMediumDate(event.time)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(event.time), alwaysUse24HourFormat: true)}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

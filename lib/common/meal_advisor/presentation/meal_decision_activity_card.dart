import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../context/meal_decision_activity_context.dart';

/// Variant 5: distinct linked planned/completed cards, with optional real history.
class MealDecisionActivityCard extends StatelessWidget {
  const MealDecisionActivityCard({
    super.key,
    required this.activity,
    required this.openRecord,
    this.openActivity,
    this.glucoseHistory,
  });

  final MealDecisionActivityContext activity;
  final VoidCallback openRecord;
  final VoidCallback? openActivity;
  final Widget? glucoseHistory;

  @override
  Widget build(BuildContext context) {
    final completed = !activity.planned && activity.endedAt != null;
    final color = activity.planned
        ? Colors.amber.shade600
        : completed
        ? Colors.green.shade300
        : Theme.of(context).colorScheme.primary;
    final time = DateFormat(
      'dd.MM HH:mm',
      context.lang.localeName,
    ).format(activity.at);
    final end = activity.endedAt;
    final period = end == null
        ? time
        : '$time–${DateFormat.Hm(context.lang.localeName).format(end)}';
    return Card.outlined(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: .6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: openRecord,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    activity.planned
                        ? Icons.event_outlined
                        : completed
                        ? Icons.task_alt
                        : Icons.directions_run,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.planned
                              ? context.lang.mealDecisionTrainingPlanned
                              : completed
                              ? context.lang.mealDecisionTrainingCompleted
                              : context.lang.mealDecisionTrainingOngoing,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: color),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          period,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (completed && glucoseHistory != null) ...[
              const SizedBox(height: 12),
              glucoseHistory!,
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),
            TextButton(
              onPressed: openRecord,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      activity.planned
                          ? context.lang.mealDecisionActivityPlanHistory
                          : context.lang.mealDecisionActivitySessionDetails,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            if (openActivity != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: openActivity,
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(context.lang.mealDecisionActivityPlanHistory),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

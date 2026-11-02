import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/manual_meal_decision.dart';
import '../../../../../common/widgets/date_time_summary_card.dart';
import '../../../data/models/retrospective_meal_timing.dart';

class MealReviewTiming extends StatelessWidget {
  const MealReviewTiming({
    super.key,
    required this.start,
    required this.onChange,
    this.timing,
  });
  final DateTime start;
  final VoidCallback onChange;
  final RetrospectiveMealTiming? timing;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String dateTime(DateTime value) =>
        '${localizations.formatMediumDate(value)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
    final past = timing;
    return DateTimeSummaryCard(
      title: past == null
          ? context.lang.addMealPlannedDateLabel
          : context.lang.uiEatingStarted,
      dateTime: start,
      actionLabel: context.lang.mealEditTime,
      onChange: onChange,
      details: past == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  mealDecisionLabel(past.choice.decision),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.lang.uiEatingDuration}: ${context.lang.mealFlowMinutes(past.eatingMinutes ?? 0)}',
                ),
                Text(
                  '${context.lang.mealFlowEatingEnd}: ${dateTime(start.add(Duration(minutes: past.eatingMinutes ?? 0)))}',
                ),
                Text(
                  '${context.lang.mealFlowInsulinTime}: ${dateTime(past.bolusAt(start))}',
                ),
                const SizedBox(height: 8),
                Text(
                  context.lang.mealRetrospectiveFullPortionNote,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

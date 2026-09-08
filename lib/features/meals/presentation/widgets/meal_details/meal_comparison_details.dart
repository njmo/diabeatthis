import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/glucose_comparison_chart.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../controllers/meal_details_controller.dart';
import 'meal_detail_formatters.dart';

class MealComparisonDetails extends ConsumerWidget {
  final int mealId;
  final MealAnalysisData current;

  const MealComparisonDetails({
    super.key,
    required this.mealId,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // History is loaded only after the user chooses a related meal.
    final state = ref.watch(mealDetailsControllerProvider(mealId));
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Text(context.lang.mealLoadError(error)),
      data: (value) {
        final previous = value.analysis;
        if (previous == null || !value.details.meal.isEaten) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.lang.mealNoAnalysisData),
          );
        }
        final currentDuration = current.chartEnd.difference(current.mealTime);
        final previousDuration = previous.chartEnd.difference(
          previous.mealTime,
        );
        final duration = currentDuration < previousDuration
            ? currentDuration
            : previousDuration;
        final first = GlucoseWindowSummary(
          readings: current.glucoseReadings,
          start: current.mealTime,
          end: current.mealTime.add(duration),
        );
        final second = GlucoseWindowSummary(
          readings: previous.glucoseReadings,
          start: previous.mealTime,
          end: previous.mealTime.add(duration),
        );
        if (first.readings.isEmpty || second.readings.isEmpty) {
          return Text(context.lang.mealNoAnalysisData);
        }
        final messages = context.lang;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              '${messages.mealReviewObservation}: ${formatDurationLabel(duration)} · mg/dl',
            ),
            const SizedBox(height: 12),
            Text(
              '━ ${messages.mealReviewCurrentMeal}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            Text(
              '┄ ${mealDateTime(previous.mealTime)}',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
            const SizedBox(height: 16),
            GlucoseComparisonChart(current: first, previous: second),
            const SizedBox(height: 12),
            Text(messages.mealReviewComparisonNote),
            const SizedBox(height: 8),
            Text(
              '${messages.mealReviewMissing}: '
              '${formatDurationLabel(first.missing)} / ${formatDurationLabel(second.missing)}',
            ),
          ],
        );
      },
    );
  }
}

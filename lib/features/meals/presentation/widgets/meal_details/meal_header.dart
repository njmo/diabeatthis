import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../models/meal_page_state.dart';
import 'meal_analysis_progress_summary.dart';
import 'meal_detail_formatters.dart';
import 'meal_macro_strip.dart';

class MealHeader extends StatelessWidget {
  final MealPageState state;
  final bool advanced;

  const MealHeader({super.key, required this.state, this.advanced = true});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final snapshot = details.preferredSummarySnapshot;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details.meal.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            mealDateTime(details.analysisTime),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (snapshot != null)
            Text(
              details.hasConsumedData
                  ? context.lang.mealReviewConsumed
                  : context.lang.mealReviewPlanned,
              style: theme.textTheme.labelMedium,
            ),
          if (snapshot != null) ...[
            const SizedBox(height: 10),
            MealMacroStrip(snapshot: snapshot),
          ],
          const SizedBox(height: 12),
          MealAnalysisProgressSummary(
            state: state,
            showCompletedStatus: advanced,
          ),
          if (details.hasLowTreatments) ...[
            const SizedBox(height: 8),
            Text(
              context.lang.mealLowTreatmentDelay(
                formatDelayAfterMeal(details.firstLowTreatmentDelay),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_category.dart';
import '../../../../../common/widgets/detail_identity_header.dart';
import '../../models/meal_page_state.dart';
import 'meal_category_edit_button.dart';
import 'meal_detail_formatters.dart';

/// The essential identity and observation state, before any optional detail.
class MealPreviewHeader extends StatelessWidget {
  final MealPageState state;

  const MealPreviewHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    final messages = context.lang;
    final complete = analysis?.hasFullGlucoseWindow == true;
    final status = !details.meal.isEaten
        ? mealStatusLabel(details.meal.status)
        : analysis == null
        ? messages.mealNoAnalysisData
        : !complete
        ? messages.mealPreviewObserving(mealTime(analysis.expectedChartEnd))
        : analysis.postMealGlucoseCoverage.hasSignificantMissing
        ? messages.mealPreviewIncomplete
        : messages.mealPreviewObservationEnded;

    return DetailIdentityHeader(
      title: details.meal.name,
      status: status,
      statusColor: details.meal.status == 'planned'
          ? null
          : Theme.of(context).colorScheme.primary,
      dateLabel: DateFormat(
        'd MMMM yyyy · HH:mm',
        messages.localeName,
      ).format(details.analysisTime),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MealCategory.fromStorage(details.meal.category) == null)
            MealCategoryEditButton(mealId: details.meal.id, assign: true),
          if (state.analysisError != null && details.meal.isEaten)
            Text(state.analysisError!),
        ],
      ),
    );
  }
}

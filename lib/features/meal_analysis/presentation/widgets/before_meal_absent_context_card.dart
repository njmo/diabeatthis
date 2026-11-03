import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/before_meal_context.dart';

class BeforeMealAbsentContextCard extends StatelessWidget {
  const BeforeMealAbsentContextCard({super.key, required this.data});
  final BeforeMealContext data;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final previous = data.precedingMeal;
    if (!(previous == null ||
        data.extendedCarbPlans?.isNotEmpty != true ||
        data.lowTreatments?.isNotEmpty != true ||
        data.recentPrecedingActivity == null)) {
      return const SizedBox.shrink();
    }
    return SummaryDetailCard(
      title: lang.mealOtherContext,
      icon: Icons.checklist,
      child: Column(
        children: [
          if (previous == null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(
                data.priorMeals == null
                    ? '${lang.beforeMealPrecedingMeal}: ${lang.beforeMealUnavailable}'
                    : lang.beforeMealNoPrecedingMeal(
                        formatDurationLabel(
                          BeforeMealContext.precedingMealWindow,
                        ),
                      ),
              ),
            ),
          if (data.extendedCarbPlans?.isNotEmpty != true)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(
                data.extendedCarbPlans == null
                    ? '${lang.beforeMealEcarbs}: ${lang.beforeMealUnavailable}'
                    : lang.beforeMealNoEcarbs,
              ),
            ),
          if (data.lowTreatments?.isNotEmpty != true)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(
                data.lowTreatments == null
                    ? '${lang.beforeMealLows}: ${lang.beforeMealUnavailable}'
                    : lang.beforeMealNoLows,
              ),
            ),
          if (data.recentPrecedingActivity == null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_run),
              title: Text(
                data.activities == null
                    ? '${lang.beforeMealRecentActivity}: ${lang.beforeMealUnavailable}'
                    : lang.beforeMealNoRecentActivity,
              ),
            ),
        ],
      ),
    );
  }
}

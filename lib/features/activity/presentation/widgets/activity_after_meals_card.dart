import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/history/recorded_immediate_carbohydrates.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../utils/activity_log_formatters.dart';

class ActivityAfterMealsCard extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  const ActivityAfterMealsCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final carbs = recordedImmediateCarbohydrates(analysis.chartTreatments)
        .where(
          (entry) =>
              entry.createdAt.isAfter(analysis.activityEnd) &&
              !entry.createdAt.isAfter(analysis.chartEnd),
        )
        .toList();
    final meals = analysis.postActivityMeals;
    return SummaryDetailCard(
      title: lang.activityAfterMeals,
      icon: Icons.restaurant_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meals.isEmpty && carbs.isEmpty)
            Text(lang.activityNoAfterMealRecords),
          for (final details in meals) ...[
            Text(
              details.meal.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${formatActivityLogTime(details.analysisTime)} · ${lang.activityMealAfterOffset(details.analysisTime.difference(analysis.activityEnd).inMinutes.toString())}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.router.push(
                  routes.MealRoute(mealId: details.meal.id),
                ),
                icon: const Icon(Icons.restaurant_menu_rounded),
                label: Text(lang.activityOpenMeal),
              ),
            ),
          ],
          if (carbs.isNotEmpty) ...[
            if (meals.isNotEmpty) const Divider(),
            Text(
              lang.activityRecordedCarbEntries,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final entry in carbs)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.carbs} g · ${formatActivityLogTime(entry.createdAt)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      lang.activityMealAfterOffset(
                        entry.createdAt
                            .difference(analysis.activityEnd)
                            .inMinutes
                            .toString(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../../meals/presentation/widgets/meal_details/meal_macro_strip.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../utils/activity_log_formatters.dart';

class ActivityLastMealCard extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  const ActivityLastMealCard({super.key, required this.analysis});
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final details = analysis.lastMeal;
    final mealTime = details?.analysisTime;
    final valid = mealTime != null && !mealTime.isAfter(analysis.activityStart) &&
      analysis.activityStart.difference(mealTime) <= const Duration(hours: 3);
    final nutrition = details?.consumedSnapshot?.nutritionTotals;
    return SummaryDetailCard(title: lang.activityLastMeal, icon: Icons.restaurant_rounded,
      actionLabel: valid ? lang.activityOpenMeal : null,
      onDetails: valid ? () => context.router.push(routes.MealRoute(mealId: details!.meal.id)) : null,
      child: !valid ? Text(lang.activityNoMealWindow) :
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(details!.meal.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${formatActivityLogTime(mealTime)} · ${lang.activityBeforeOffset(analysis.activityStart.difference(mealTime).inMinutes.toString())}'),
          if (nutrition != null) ...[const SizedBox(height: 16), MealMacroStrip(nutrition: nutrition)],
        ]));
  }
}

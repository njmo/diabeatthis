import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_nutrition.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../demo/meal_decision_demo_snapshot.dart';
import 'meal_decision_demo_notice.dart';
import 'meal_decision_demo_similar_meal.dart';

/// Sample-only navigation. No fabricated ID is routed into a real meal record.
class MealDecisionDemoMealLink extends StatelessWidget {
  const MealDecisionDemoMealLink({
    super.key,
    required this.mealName,
    required this.snapshot,
  });
  final String mealName;
  final MealDecisionDemoSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: ListTile(
      leading: const Icon(Icons.restaurant_outlined),
      title: Text(mealName),
      subtitle: Text(
        context.lang.mealDecisionDemoPlannedAt(
          DateFormat.Hm(context.lang.localeName).format(snapshot.capturedAt),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MealStartSheet(
          title: mealName,
          subtitle: context.lang.mealDecisionDemoMealReview,
          onClose: () => Navigator.of(context).pop(),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MealDecisionDemoNotice(),
              const SizedBox(height: 16),
              MealStartNutrition(
                carbsGrams: snapshot.carbs,
                extendedCarbsGrams: snapshot.extendedCarbs,
                scheduleSettings:
                    const ExtendedCarbsScheduleSettings.defaults(),
              ),
              const SizedBox(height: 20),
              Text(
                context.lang.similarMealsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(context.lang.mealDecisionDemoSimilarDisclaimer),
              for (final daysAgo in [1, 7])
                MealDecisionDemoSimilarMeal(
                  mealName: mealName,
                  snapshot: snapshot,
                  daysAgo: daysAgo,
                ),
            ],
          ),
          actions: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/platform/aaps_suggestion_prompt.dart';
import '../../../dashboard/data/utils/meal_advisor.dart';
import '../../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'meal_summary_aaps_suggestion.dart';
import 'meal_summary_carbs_delta.dart';

Future<void> openMealAapsCarbsSuggestion({
  required BuildContext context,
  required WidgetRef ref,
  required int mealId,
  String? mealName,
  required MealSummaryAapsCarbs aapsCarbs,
}) async {
  final carbs = aapsCarbs;
  if (!shouldOpenAapsForMealSummaryAapsCarbs(carbs)) return;
  final schedule = carbs.extendedCarbs > 0
      ? MealAdvisor(
          config: MealAdvisorConfig(
            extendedCarbsScheduleSettings: await ref.read(
              extendedCarbsScheduleSettingsProvider.future,
            ),
          ),
        ).getPostMealExtendedCarbsScheduleSettings()
      : null;
  final event = buildMealSummaryAapsSuggestionEvent(
    aapsCarbs: carbs,
    extendedCarbsScheduleSettings: schedule,
    mealId: mealId,
    mealName: mealName,
    extendedCarbsAreAdditional: true,
  );
  if (event != null && context.mounted) {
    await openAapsWithSuggestionNotification(
      context: context,
      ref: ref,
      event: event,
    );
  }
}

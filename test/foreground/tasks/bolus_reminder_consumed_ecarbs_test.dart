import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/bolus_reminder_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  const meal = Meal(
    id: 1,
    name: 'Meal',
    status: 'waiting-for-bolus',
    carbs: 50,
  );
  const schedule = ExtendedCarbsScheduleSettings(
    deliveryMode: ExtendedCarbsDeliveryMode.extraBolus,
    delayMinutes: 30,
    durationMinutes: 90,
  );
  final advice = MealAdvice.full(
    MealDecision.eatNowBolusLater,
    null,
    DateTime(2026, 11, 1),
    extendedCarbs: const WbtExtendedCarbsSuggestion(
      kcal: 220,
      wbt: 2.2,
      grams: 22,
      scheduleSettings: schedule,
    ),
  );

  for (final scenario in [
    (fat: 5.0, protein: 2.5, carbs: 10.0, expected: 0),
    (fat: 10.0, protein: 5.0, carbs: 20.0, expected: 11),
    (fat: 0.0, protein: 0.0, carbs: 0.0, expected: 0),
  ]) {
    test(
      'consumed reminder refreshes macros and uses ${scenario.expected} eCarbs instead of stored 22',
      () async {
        var macros = MealMacroSummary(
          carbsGrams: 50,
          fatGrams: 20,
          proteinGrams: 10,
          fiberGrams: 0,
          totalGrams: 200,
        );
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            mealMacronutrientsConsumedSummaryProvider(1).overrideWith((
              ref,
            ) async {
              reads++;
              return macros;
            }),
          ],
        );
        final subscription = container.listen(
          mealMacronutrientsConsumedSummaryProvider(1),
          (_, _) {},
        );
        addTearDown(() {
          subscription.close();
          container.dispose();
        });
        await container.read(
          mealMacronutrientsConsumedSummaryProvider(1).future,
        );
        macros = MealMacroSummary(
          carbsGrams: scenario.carbs,
          fatGrams: scenario.fat,
          proteinGrams: scenario.protein,
          fiberGrams: 0,
          totalGrams: 50,
        );
        final result = await BolusReminderHelper().resolveMealBolusSuggestion(
          FakeRuntimeHarness(container: container).runtimeContext,
          meal,
          consumed: true,
          advice: advice,
        );
        expect(reads, 2);
        expect(result.carbs, scenario.carbs.toInt());
        expect(result.extendedCarbs, scenario.expected);
        expect(result.extendedCarbsDeliveryMode, schedule.deliveryMode);
        expect(result.extendedCarbsDelayMinutes, schedule.delayMinutes);
        expect(result.extendedCarbsDurationMinutes, schedule.durationMinutes);
        expect(advice.extendedCarbs.grams, 22);
      },
    );
  }

  test(
    'before eating retains the stored suggestion and does not read consumed amounts',
    () async {
      final container = ProviderContainer(
        overrides: [
          mealMacronutrientsConsumedSummaryProvider(
            1,
          ).overrideWith((ref) => throw StateError('Not consumed yet')),
        ],
      );
      addTearDown(container.dispose);
      final result = await BolusReminderHelper().resolveMealBolusSuggestion(
        FakeRuntimeHarness(container: container).runtimeContext,
        meal,
        advice: advice,
      );
      expect(result.carbs, 50);
      expect(result.extendedCarbs, 22);
    },
  );

  test(
    'a standalone accepted carb amount needs no database and invents no consumed eCarbs',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final result = await BolusReminderHelper().resolveMealBolusSuggestion(
        FakeRuntimeHarness(container: container).runtimeContext,
        meal,
        consumed: true,
        advice: advice,
      );
      expect(result.carbs, 50);
      expect(result.extendedCarbs, 0);
    },
  );
}

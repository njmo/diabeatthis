import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_reason.dart';
import 'package:diabeatthis/features/meal_advisor/domain/services/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/get_meal_advice_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

// Characterization cases, not assertions of clinical appropriateness.
// Keep these explicit when reviewing a future decision algorithm version.
void main() {
  final advisor = MealAdvisor();

  test('calculation estimates retain their established values', () {
    expect(
      advisor.calculateTafMinutes(carbsG: 40, fatG: 0, proteinG: 0, fiberG: 0),
      12,
    );
    expect(
      advisor.calculateTafMinutes(
        carbsG: 100,
        fatG: 30,
        proteinG: 50,
        fiberG: 10,
      ),
      45,
    );
    expect(
      advisor.calculateTafMinutes(
        carbsG: 100,
        fatG: 20,
        proteinG: 30,
        fiberG: 5,
      ),
      35,
    );
    expect(advisor.calculateTtlMinutes(bg: 180, trend: 0, iob: 2, cob: 0), 46);
    expect(advisor.calculateTtlMinutes(bg: 180, trend: 0, iob: 0, cob: 0), 240);
    expect(
      advisor.calculateTtlMinutes(bg: 220, trend: -1, iob: 0, cob: 0),
      150,
    );
    expect(advisor.calculateTtlMinutes(bg: 180, trend: 1, iob: 3, cob: 0), 42);
  });

  test('mixed meal flips high flat BG from waiting to delayed bolus', () {
    final small = advisor.getMealAdvice(
      bg: 180,
      iob: 2,
      cob: 0,
      trend: 0,
      mealCarbs: 40,
      fatGrams: 0,
      proteinGrams: 0,
      fiberGrams: 0,
    );
    final large = advisor.getMealAdvice(
      bg: 180,
      iob: 2,
      cob: 0,
      trend: 0,
      mealCarbs: 100,
      fatGrams: 30,
      proteinGrams: 50,
      fiberGrams: 10,
    );
    expect(small.reason, MealAdviceReason.highBgNotFalling);
    expect(small.decision, MealDecision.bolusWaitThenEat);
    expect(large.reason, MealAdviceReason.lowBeforeMealEffect);
    expect(large.decision, MealDecision.eatNowBolusLater);
  });

  test('carbohydrate quantity alone does not change timing above 10 grams', () {
    final results = [10.0, 40.0, 100.0, 200.0].map(
      (carbs) => advisor.getMealAdvice(
        bg: 180,
        iob: 2,
        cob: 0,
        trend: 0,
        mealCarbs: carbs,
        fatGrams: 0,
        proteinGrams: 0,
        fiberGrams: 0,
      ),
    );
    for (final result in results) {
      expect(result.decision, MealDecision.bolusWaitThenEat);
    }
  });

  test('large meal does not always delay bolus when IOB is zero', () {
    final result = advisor.getMealAdvice(
      bg: 180,
      iob: 0,
      cob: 0,
      trend: 0,
      mealCarbs: 100,
      fatGrams: 30,
      proteinGrams: 50,
      fiberGrams: 10,
    );
    expect(result.reason, MealAdviceReason.highBgNotFalling);
    expect(result.decision, MealDecision.bolusWaitThenEat);
  });

  test('high but falling BG skips waiting outside the near-low zone', () {
    final result = advisor.getMealAdvice(
      bg: 220,
      iob: 0,
      cob: 0,
      trend: -1,
      mealCarbs: 100,
      fatGrams: 30,
      proteinGrams: 50,
      fiberGrams: 10,
    );
    expect(result.reason, MealAdviceReason.immediateMeal);
    expect(result.decision, MealDecision.bolusAndEatNow);
    expect(result.wait, isNull);
  });

  test('near-low IOB rule takes precedence over high rising BG', () {
    final result = advisor.getMealAdvice(
      bg: 180,
      iob: 3,
      cob: 0,
      trend: 1,
      mealCarbs: 100,
      fatGrams: 20,
      proteinGrams: 30,
      fiberGrams: 5,
    );
    expect(result.reason, MealAdviceReason.nearLowWithLowBgOrIob);
    expect(result.decision, MealDecision.eatNowBolusLater);
  });

  test('large meal safety and near-low boundaries are inclusive', () {
    for (final entry in {
      50: MealAdviceReason.lowBeforeMealEffect,
      51: MealAdviceReason.nearLowWithLowBgOrIob,
      70: MealAdviceReason.nearLowWithLowBgOrIob,
      71: MealAdviceReason.highBgNotFalling,
    }.entries) {
      expect(
        advisor.decideReason(
          bg: 180,
          trend: 0,
          iob: 2,
          tafMinutes: 45,
          ttlMinutes: entry.key,
        ),
        entry.value,
        reason: 'TTL=${entry.key}',
      );
    }
  });

  for (final tick in ['-7.5', '-7,5', 'invalid', '']) {
    test(
      'characterizes discarded tick "$tick" as flat in shared entry point',
      () {
        final result = const GetMealAdviceUseCase()(
          macros: MealMacroSummary(
            carbsGrams: 100,
            netCarbsGrams: 100,
            fatGrams: 30,
            proteinGrams: 50,
            fiberGrams: 10,
            totalGrams: 400,
          ),
          deviceStatus: testDeviceStatus(
            date: DateTime(2026, 9, 9),
            bg: 220,
            iob: 0,
            cob: 0,
            tick: tick,
          ),
          settings: const ExtendedCarbsScheduleSettings.defaults(),
        );
        expect(result.reason, MealAdviceReason.highBgNotFalling);
        expect(result.decision, MealDecision.bolusWaitThenEat);
      },
    );
  }
}

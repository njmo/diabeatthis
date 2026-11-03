import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/get_meal_advice_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  for (final bg in [80, 120, 190]) {
    test(
      'activity proposal survives advisor result for BG $bg without changing meal timing',
      () {
        const useCase = GetMealAdviceUseCase();
        final macros = MealMacroSummary(
          carbsGrams: 45,
          fatGrams: 10,
          proteinGrams: 15,
          fiberGrams: 0,
          totalGrams: 200,
        );
        final status = testDeviceStatus(
          date: DateTime(2026, 11, 3),
          bg: bg,
          iob: 0.5,
          cob: 0,
          tick: '0',
        );
        final proposal = MealActivityDoseSuggestion(
          dosePercent: 80,
          activityName: 'Walk',
          startedAt: status.date,
          phase: MealActivityPhase.upcoming,
        );
        final normal = useCase(
          macros: macros,
          deviceStatus: status,
          settings: const ExtendedCarbsScheduleSettings.defaults(),
        );
        final actual = useCase(
          macros: macros,
          deviceStatus: status,
          settings: const ExtendedCarbsScheduleSettings.defaults(),
          activityDoseSuggestion: proposal,
        );
        expect(actual.activityDoseSuggestion, same(proposal));
        expect(actual.decision, normal.decision);
        expect(
          actual.wait?.recommendedMinutes,
          normal.wait?.recommendedMinutes,
        );
        expect(actual.extendedCarbs.grams, normal.extendedCarbs.grams);
      },
    );
  }
}

import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_config.dart';
import 'package:diabeatthis/features/meal_advisor/domain/services/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/get_meal_advice_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  const useCase = GetMealAdviceUseCase();
  const settings = ExtendedCarbsScheduleSettings(
    delayMinutes: 60,
    durationMinutes: 180,
  );
  final macros = MealMacroSummary(
    carbsGrams: 80,
    netCarbsGrams: 60,
    fatGrams: 15,
    proteinGrams: 25,
    fiberGrams: 5,
    totalGrams: 300,
  );

  for (final entry in {'+5': 1, '-10': -2, '0': 0, '+2.5': 0, '': 0}.entries) {
    test(
      'preserves existing conversion for tick "${entry.key}" and uses net carbs',
      () {
        final status = testDeviceStatus(
          date: DateTime(2026, 9, 9),
          bg: 190,
          iob: 0.5,
          cob: 0,
          tick: entry.key,
        );
        final actual = useCase(
          macros: macros,
          deviceStatus: status,
          settings: settings,
        );
        final expected =
            MealAdvisor(
              config: const MealAdvisorConfig(
                extendedCarbsScheduleSettings: settings,
              ),
            ).getMealAdvice(
              bg: 190,
              iob: 0.5,
              cob: 0,
              trend: entry.value,
              mealCarbs: 60,
              fatGrams: 15,
              proteinGrams: 25,
              fiberGrams: 5,
            );
        expect(actual.decision, expected.decision);
        expect(
          actual.wait?.recommendedMinutes,
          expected.wait?.recommendedMinutes,
        );
        expect(actual.wait?.minMinutes, expected.wait?.minMinutes);
        expect(actual.wait?.maxMinutes, expected.wait?.maxMinutes);
        expect(actual.extendedCarbs.grams, expected.extendedCarbs.grams);
        expect(actual.extendedCarbs.scheduleSettings.delayMinutes, 60);
        expect(actual.extendedCarbs.scheduleSettings.durationMinutes, 180);
      },
    );
  }
}

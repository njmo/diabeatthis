import 'package:diabeatthis/features/dashboard/data/models/persisted_meal_advisor_result.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saveMealAdvice stores nullable extended carbs schedule without WBT',
    () async {
      final store = FakeMealAdvisorResultStore();
      final useCase = MealAdvisorResultUseCase(store);

      await useCase.saveMealAdvice(
        1,
        MealAdvice(MealDecision.bolusAndEatNow, null),
      );

      expect(store.savedResult?.extendedCarbsGrams, 0);
      expect(store.savedResult?.extendedCarbsDeliveryMode, isNull);
      expect(store.savedResult?.extendedCarbsDelayMinutes, isNull);
      expect(store.savedResult?.extendedCarbsDurationMinutes, isNull);
    },
  );

  test(
    'saveMealAdvice stores extended carbs schedule when WBT is suggested',
    () async {
      final store = FakeMealAdvisorResultStore();
      final useCase = MealAdvisorResultUseCase(store);

      await useCase.saveMealAdvice(
        1,
        MealAdvice(
          MealDecision.bolusAndEatNow,
          null,
          extendedCarbs: const WbtExtendedCarbsSuggestion(
            kcal: 220,
            wbt: 2.2,
            grams: 22,
            scheduleSettings: ExtendedCarbsScheduleSettings(
              delayMinutes: 30,
              durationMinutes: 90,
            ),
          ),
        ),
      );

      expect(store.savedResult?.extendedCarbsGrams, 22);
      expect(
        store.savedResult?.extendedCarbsDeliveryMode,
        ExtendedCarbsDeliveryMode.extendedCarbs.name,
      );
      expect(store.savedResult?.extendedCarbsDelayMinutes, 30);
      expect(store.savedResult?.extendedCarbsDurationMinutes, 90);
    },
  );
}

class FakeMealAdvisorResultStore implements MealAdvisorResultStore {
  PersistedMealAdvisorResult? savedResult;

  @override
  Future<PersistedMealAdvisorResult?> getMealAdvisorResult(int mealId) async {
    return savedResult;
  }

  @override
  Future<int> insertMealAdvisorResult(PersistedMealAdvisorResult result) async {
    savedResult = result;
    return 1;
  }
}

import 'package:diabeatthis/features/dashboard/data/models/persisted_meal_advisor_result.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    'eating-then-bolus': MealDecision.eatNowBolusLater,
    'bolused-eating': MealDecision.bolusAndEatNow,
    'bolused-waiting': MealDecision.bolusWaitThenEat,
  }.entries) {
    test('manual result reconstructs ${entry.value} from history', () async {
      final store = FakeMealAdvisorResultStore()..statuses = [entry.key];
      final useCase = MealAdvisorResultUseCase(store);
      await useCase.saveMealAdvice(
        9,
        MealAdvice(entry.value, null, source: 'manual'),
      );
      expect(store.savedResult!.result, 'manual');
      expect((await useCase.loadMealAdvice(9))!.decision, entry.value);
    });
    test('existing ${entry.key} remains an advisor result', () async {
      final store = FakeMealAdvisorResultStore();
      final useCase = MealAdvisorResultUseCase(store);
      await useCase.saveMealAdvice(9, MealAdvice(entry.value, null));
      expect(store.savedResult!.result, entry.key);
      expect((await useCase.loadMealAdvice(9))!.source, 'mealAdvisor');
    });
  }

  test('manual decision and selected wait survive persistence', () async {
    final store = FakeMealAdvisorResultStore();
    final useCase = MealAdvisorResultUseCase(store);
    await useCase.saveMealAdvice(
      7,
      MealAdvice(
        MealDecision.bolusWaitThenEat,
        WaitSuggestion(12, 12, 12),
        source: 'manual',
      ),
    );
    expect(store.savedResult!.result, 'manual');
    expect(store.savedResult!.waitTimeIgnored, isFalse);
    final loaded = await useCase.loadMealAdvice(7);
    expect(loaded!.source, 'manual');
    expect(loaded.decision, MealDecision.bolusWaitThenEat);
    expect(loaded.wait!.recommendedMinutes, 12);
  });

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
  List<String> statuses = [];

  @override
  Future<List<String>> getMealStatusHistory(int mealId) async => statuses;

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

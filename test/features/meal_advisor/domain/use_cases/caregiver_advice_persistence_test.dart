import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'caregiver attribution survives persistence and legacy rows keep their source',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal (id, name, planned_at) VALUES (1, 'Meal', 1000), (2, 'Old meal', 2000), (3, 'Old manual', 3000)",
      );
      final useCase = MealAdvisorResultUseCase(
        DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
      );
      await useCase.saveMealAdvice(
        1,
        MealAdvice(
          MealDecision.bolusAndEatNow,
          null,
          source: 'caregiver',
          caregiverId: 'caregiver-1',
          caregiverRequestId: 'request-1',
        ),
      );
      final loaded = (await useCase.loadMealAdvice(1))!;
      expect(loaded.source, 'caregiver');
      expect(loaded.caregiverId, 'caregiver-1');
      expect(loaded.caregiverRequestId, 'request-1');
      await db.customStatement(
        "INSERT INTO meal_advisor_result (meal_id, result, initial_wait_time, final_wait_time, wait_time_ignored) VALUES (2, 'bolused-eating', 0, 0, 1), (3, 'manual', 0, 0, 0)",
      );
      expect((await useCase.loadMealAdvice(2))!.source, 'mealAdvisor');
      expect((await useCase.loadMealAdvice(3))!.source, 'manual');
    },
  );
}

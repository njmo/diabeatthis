import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice.dart';
import 'package:diabeatthis/features/meal_advisor/domain/services/meal_advisor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealAdvice advice() => MealAdvisor().getMealAdvice(
    bg: 180,
    iob: 2,
    cob: 0,
    trend: 0,
    mealCarbs: 100,
    fatGrams: 30,
    proteinGrams: 40,
    fiberGrams: 10,
  );

  test(
    'Drift preserves the decision and calculation time without a trace copy',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal (name, planned_at) VALUES ('Meal', 1000)",
      );
      final calculatedAt = DateTime(2026, 9, 9, 12);
      final result = withClock(Clock.fixed(calculatedAt), advice);
      final useCase = MealAdvisorResultUseCase(
        DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
      );
      await useCase.saveMealAdvice(1, result);
      final row = (await db.select(db.mealAdvisorResult).get()).single;
      expect(row.decisionReason, result.reason!.name);
      expect(row.version, MealAdvisor.algorithmVersion);
      expect(row.createdAt, calculatedAt.millisecondsSinceEpoch);
      final loaded = (await useCase.loadMealAdvice(1))!;
      expect(loaded.createdAt, calculatedAt);
      expect(loaded.decision, result.decision);
      expect(loaded.reason, result.reason);
      await db.customStatement(
        "UPDATE meal_advisor_result SET decision_reason = 'unknown-old-reason' WHERE meal_id = 1",
      );
      expect((await useCase.loadMealAdvice(1))!.reason, isNull);
      expect((await useCase.loadMealAdvice(1))!.decision, result.decision);
      await db.customStatement(
        "INSERT INTO meal (name, planned_at) VALUES ('Manual meal', 2000)",
      );
      await useCase.saveMealAdvice(
        2,
        MealAdvice(
          result.decision,
          null,
          source: 'manual',
          reason: result.reason,
        ),
      );
      final manual = await db.mealAdvisorResultDao.getMealAdvisorResult(2);
      expect(manual!.decisionReason, isNull);
      expect(manual.version, isNull);
    },
  );
}

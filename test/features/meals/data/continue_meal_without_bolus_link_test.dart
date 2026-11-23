import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/continue_meal_without_bolus_link.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (decision, status) in [
    (MealDecision.eatNowBolusLater, 'eaten-bolused'),
    (MealDecision.bolusAndEatNow, 'bolused-eating'),
    (MealDecision.bolusWaitThenEat, 'bolused-waiting'),
  ]) {
    test(
      'manual confirmation resumes $decision without linking a treatment',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Lunch',
                status: const Value('waiting-for-bolus'),
              ),
            );
        await MealAdvisorResultUseCase(
          DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
        ).saveMealAdvice(id, MealAdvice.full(decision, null, DateTime.now()));

        expect(await continueMealWithoutBolusLink(db, id), isTrue);
        expect((await db.mealDao.getMealById(id))?.status, status);
        expect(await db.mealWizardLinkDao.forMeal(id), isEmpty);
        expect(await continueMealWithoutBolusLink(db, id), isFalse);
      },
    );
  }

  test('manual confirmation cannot revive an interrupted meal', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Lunch',
            status: const Value('interrupted'),
          ),
        );
    expect(await continueMealWithoutBolusLink(db, id), isFalse);
    expect((await db.mealDao.getMealById(id))?.status, 'interrupted');
  });
}

import 'package:diabeatthis/common/meal/meal_activation_guard.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/apply_meal_add_on_multiplier_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'complete_meal_use_case_test.dart' show seedCompletionMeal;

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await seedCompletionMeal(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<MealAddOnMultiplierResult> addOn({double multiplier = 1.5}) =>
      container
          .read(applyMealAddOnMultiplierUseCaseProvider)
          .call(mealId: 1, currentMealStatus: 'eating', multiplier: multiplier);

  for (final status in ['interrupted', 'summarized', 'eaten']) {
    test('stale quick add-on cannot alter a meal now $status', () async {
      await db.mealDao.updateMealStatus(1, status);
      await expectLater(addOn(), throwsA(isA<MealActivationException>()));
      expect((await db.mealDao.getMealById(1))!.status, status);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
    });
  }

  test('quick add-on cannot bypass a second active meal', () async {
    await db.customInsert(
      "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Other meal',1793520000000,'bolused-eating')",
    );
    await expectLater(addOn(), throwsA(isA<MealActivationException>()));
    expect((await db.mealDao.getMealById(1))!.status, 'eating');
    expect(
      (await db.mealIngredientsDao.getMealIngredientsForMeal(
        1,
      )).single.consumedAmount,
      isNull,
    );
  });

  for (final multiplier in [double.nan, double.infinity, -1.0, 0.0]) {
    test('invalid multiplier $multiplier cannot write consumption', () async {
      await expectLater(
        addOn(multiplier: multiplier),
        throwsA(isA<MealActivationException>()),
      );
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
    });
  }
}

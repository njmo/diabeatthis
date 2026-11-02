import 'package:diabeatthis/common/meal/meal_activation_guard.dart';
import 'package:diabeatthis/core/domain/model/meal_status_flow.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/accept_meal_decision_use_case.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final acceptProvider = Provider((ref) => AcceptMealDecisionUseCase(ref));
  final plannedAt = DateTime(2026, 11, 1, 12);
  late DatabaseImpl db;
  late ProviderContainer container;
  var mealSequence = 0;

  Future<int> createMeal({
    String status = 'planned',
    String purpose = 'meal',
  }) async {
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Lunch ${++mealSequence}',
            plannedAt: plannedAt.millisecondsSinceEpoch,
            status: Value(status),
            purpose: Value(purpose),
          ),
        );
    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: id,
            ingredientId: 1,
            amount: const Value(100),
            quantityConfidence: 1,
          ),
        );
    return id;
  }

  Future<void> accept(
    int id, [
    MealDecision decision = MealDecision.eatNowBolusLater,
  ]) => container.read(acceptProvider)(
    id,
    MealAdvice(decision, null, source: 'manual'),
  );

  setUp(() async {
    mealSequence = 0;
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Rice',
            carbsPer100g: 20,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 2,
            nutritionConfidence: 1,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final decision in [
    MealDecision.eatNowBolusLater,
    MealDecision.bolusAndEatNow,
    MealDecision.bolusWaitThenEat,
  ]) {
    test(
      'a planned meal still accepts $decision with its original snapshot',
      () async {
        final id = await createMeal();
        await accept(id, decision);
        expect(
          (await db.mealDao.getMealById(id))!.status,
          decision.acceptedStatus,
        );
        expect(await db.select(db.mealAdvisorResult).get(), hasLength(1));
        expect((await db.select(db.mealSnapshot).getSingle()).totalGrams, 100);
      },
    );
  }

  for (final status in [
    'summarized',
    'interrupted',
    'waiting-for-bolus',
    'eating',
    'skipped',
  ]) {
    test(
      'stale acceptance cannot change $status advice, snapshot, or history',
      () async {
        final id = await createMeal();
        await db.mealDao.updateMealStatus(id, status);
        final before = await db.mealDao.getMealById(id);
        final history = await db.select(db.mealStatusHistory).get();
        await expectLater(accept(id), throwsA(isA<MealActivationException>()));
        expect(await db.mealDao.getMealById(id), before);
        expect(await db.select(db.mealStatusHistory).get(), history);
        expect(await db.select(db.mealAdvisorResult).get(), isEmpty);
        expect(await db.select(db.mealSnapshot).get(), isEmpty);
      },
    );
  }

  for (final status in mealStatusesBlockingAnotherMealActivation) {
    test(
      'another meal becoming $status before confirmation blocks all writes',
      () async {
        final id = await createMeal();
        final other = await createMeal();
        await db.mealDao.updateMealStatus(other, status);
        final history = await db.select(db.mealStatusHistory).get();
        await expectLater(accept(id), throwsA(isA<MealActivationException>()));
        expect((await db.mealDao.getMealById(id))!.status, 'planned');
        expect((await db.mealDao.getMealById(other))!.status, status);
        expect(await db.select(db.mealStatusHistory).get(), history);
        expect(await db.select(db.mealAdvisorResult).get(), isEmpty);
        expect(await db.select(db.mealSnapshot).get(), isEmpty);
      },
    );
  }

  test('simultaneous confirmations commit only one active meal', () async {
    final first = await createMeal();
    final second = await createMeal();
    final accepted = await Future.wait([
      for (final id in [first, second])
        accept(id).then((_) => true).catchError((Object error) {
          expect(error, isA<MealActivationException>());
          return false;
        }),
    ]);
    expect(accepted.where((value) => value), hasLength(1));
    expect(await db.select(db.mealAdvisorResult).get(), hasLength(1));
    expect(await db.select(db.mealSnapshot).get(), hasLength(1));
    final meals = await db.select(db.meal).get();
    expect(meals.where((meal) => meal.status == 'planned'), hasLength(1));
    expect(
      meals.where((meal) => meal.status == 'eating-then-bolus'),
      hasLength(1),
    );
  });

  test(
    'a separate low treatment cannot block ordinary meal acceptance',
    () async {
      final id = await createMeal();
      await createMeal(status: 'eating', purpose: 'lowTreatment');
      await accept(id);
      expect((await db.mealDao.getMealById(id))!.status, 'eating-then-bolus');
    },
  );
}

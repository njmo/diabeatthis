import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide Treat;
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_handoff_repository.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '4g then 4g confirms a 7g intake and persists the returned 8g',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final at = DateTime.utc(2026, 11, 3, 12);
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Low treatment',
              plannedAt: at.millisecondsSinceEpoch,
              purpose: const Value('lowTreatment'),
              status: const Value('confirmed'),
            ),
          );
      await db
          .into(db.lowTreatmentContext)
          .insert(
            LowTreatmentContextCompanion.insert(
              mealId: Value(id),
              source: 'manual',
              recordedCarbs: const Value(7),
            ),
          );
      final repository = LowTreatmentHandoffRepository(db);
      await repository.register(
        mealId: id,
        savedAt: at,
        expectedCarbs: 7,
        suggestionAt: null,
      );
      final first = Treat(
        externalId: 'one',
        createdAt: at.add(const Duration(seconds: 20)),
        carbs: 4,
      );
      final second = Treat(
        externalId: 'two',
        createdAt: at.add(const Duration(seconds: 40)),
        carbs: 4,
      );
      expect(
        await repository.reconcile([
          first,
        ], at.add(const Duration(seconds: 30))),
        isEmpty,
      );
      expect(
        (await RecordedLowTreatmentRepository(
          db,
        ).fetchByMealId(id))!.netCarbsGrams,
        7,
      );
      expect(
        await repository.reconcile([
          first,
          first,
          second,
        ], at.add(const Duration(minutes: 1))),
        hasLength(1),
      );
      expect(
        (await RecordedLowTreatmentRepository(
          db,
        ).fetchByMealId(id))!.netCarbsGrams,
        8,
      );
      expect(await db.select(db.lowTreatmentReview).get(), hasLength(2));
      expect(
        await repository.reconcile([
          first,
          second,
        ], at.add(const Duration(minutes: 2))),
        hasLength(1),
      );
      expect(
        (await RecordedLowTreatmentRepository(
          db,
        ).fetchByMealId(id))!.netCarbsGrams,
        8,
      );
    },
  );

  test(
    'source repository rounds nutrient-derived intake before any handoff sees it',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Low treatment',
              plannedAt: 1000,
              purpose: const Value('lowTreatment'),
              status: const Value('confirmed'),
            ),
          );
      final ingredient = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Glucose',
              carbsPer100g: 100,
              proteinPer100g: 0,
              fatPer100g: 0,
              fiberPer100g: 0,
              nutritionConfidence: 1,
            ),
          );
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: id,
              ingredientId: ingredient,
              amount: const Value(7.35),
              consumedAmount: const Value(7.35),
              quantityConfidence: 1,
            ),
          );
      expect(
        (await RecordedLowTreatmentRepository(
          db,
        ).fetchByMealId(id))!.netCarbsGrams,
        7,
      );
    },
  );
}

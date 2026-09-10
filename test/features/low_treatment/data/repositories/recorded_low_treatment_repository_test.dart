import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  final end = DateTime.utc(2026, 9, 10, 12);
  final start = end.subtract(const Duration(hours: 2));
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> insert(
    DateTime at, {
    String purpose = 'lowTreatment',
    String status = 'confirmed',
  }) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: 'Test $purpose $status',
          plannedAt: at.millisecondsSinceEpoch,
          purpose: Value(purpose),
          status: Value(status),
        ),
      );

  test(
    'only saved consumption inside the inclusive window; late entries remain analysis context',
    () async {
      final first = await insert(start);
      final last = await insert(end);
      await insert(start.subtract(const Duration(milliseconds: 1)));
      await insert(end.add(const Duration(milliseconds: 1)));
      await insert(end, purpose: 'meal');
      await insert(end, status: 'draft');
      final records = await RecordedLowTreatmentRepository(
        db,
      ).fetchBetween(start, end);
      expect(records.map((e) => e.mealId), [first, last]);
      expect(records.first.netCarbsGrams, isNull);
      expect(records.first.reason, isNull);
      expect(records.first.suggestedCarbs, isNull);
    },
  );

  test(
    'uses saved consumed quantity, separately from the AAPS suggestion',
    () async {
      final mealId = await insert(end);
      final ingredientId = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Glucose',
              carbsPer100g: 100,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
            ),
          );
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: mealId,
              ingredientId: ingredientId,
              amount: const Value(15),
              consumedAmount: const Value(10),
              quantityConfidence: 1,
            ),
          );
      await db
          .into(db.lowTreatmentContext)
          .insert(
            LowTreatmentContextCompanion.insert(
              mealId: Value(mealId),
              source: 'aapsSuggestion',
              suggestedCarbs: const Value(12),
              reason: const Value('carbsReq'),
            ),
          );
      final repository = RecordedLowTreatmentRepository(db);
      final result = (await repository.fetchBetween(start, end)).single;
      expect(result.netCarbsGrams, 10);
      expect(result.suggestedCarbs, 12);
      expect(result.reason!.name, 'carbsReq');
      // Reopening the analysis reads current source records, not an advisor copy.
      await (db.update(db.mealIngredients)
            ..where((t) => t.mealId.equals(mealId)))
          .write(const MealIngredientsCompanion(consumedAmount: Value(8)));
      expect(
        (await repository.fetchBetween(start, end)).single.netCarbsGrams,
        8,
      );
    },
  );
}

import 'package:diabeatthis/core/drift/database_impl.dart'
    hide AcceptedDaySummary;
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_dml_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_summary_snapshot_use_case.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/critical_day_context.dart';

void main() {
  test(
    'whole-gram delivery rounding must not inflate historical low-treatment nutrition in the day summary',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final start = DateTime(2026, 9, 1);
      final ingredient = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Glucose',
              carbsPer100g: 100,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
              carbsLabelMode: const Value('eu'),
              createdAt: Value(
                start.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
              ),
            ),
          );
      for (final entry in [(hour: 12, grams: 7.6), (hour: 13, grams: 2.6)]) {
        final at = start
            .add(Duration(hours: entry.hour))
            .millisecondsSinceEpoch;
        final meal = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Recorded rescue',
                plannedAt: at,
                purpose: const Value('lowTreatment'),
                status: const Value('confirmed'),
                createdAt: Value(at),
                updatedAt: Value(at),
              ),
            );
        await db
            .into(db.mealIngredients)
            .insert(
              MealIngredientsCompanion.insert(
                mealId: meal,
                ingredientId: ingredient,
                amount: Value(entry.grams),
                consumedAmount: Value(entry.grams),
                quantityConfidence: 1,
                consumedConfidence: const Value(1),
                createdAt: Value(at),
                updatedAt: Value(at),
              ),
            );
        await db
            .into(db.mealSnapshot)
            .insert(
              MealSnapshotCompanion.insert(
                mealId: meal,
                snapshotType: 'consumed',
                totalGrams: entry.grams,
                totalCarbsG: entry.grams,
                totalFiberG: 0,
                totalNetCarbsG: entry.grams,
                totalFatG: 0,
                totalProteinG: 0,
                totalCaloriesKcal: entry.grams * 4,
                createdAt: Value(at),
                updatedAt: Value(at),
              ),
            );
      }
      final persisted = await db.select(db.mealSnapshot).get();
      expect(
        persisted.fold<double>(0, (sum, row) => sum + row.totalNetCarbsG),
        closeTo(10.2, .000001),
      );
      final lows = await RecordedLowTreatmentRepository(
        db,
      ).fetchBetween(start, start.add(const Duration(days: 1)));
      final snapshot = const BuildDaySummarySnapshotUseCase()(
        criticalDayContext(lows: lows),
        meals: [],
        lows: [],
      );
      expect(
        snapshot.metrics[DaySummaryMetric.lowTreatmentCarbsGrams],
        closeTo(10.2, .000001),
      );
      final dml = const BuildDayDmlUseCase()(
        AcceptedDaySummary(
          snapshot: snapshot,
          acceptedAt: DateTime(2026, 9, 2, 9),
        ),
      ).text;
      expect(dml, contains('"confirmed_carbs_g":10.2'));
    },
  );
}

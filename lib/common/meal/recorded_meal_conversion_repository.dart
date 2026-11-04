import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';
import 'recorded_meal_conversion_request.dart';

/// Missing factors require review; existing historical values are never replaced.
class RecordedMealConversionRepository {
  final DatabaseImpl db;
  const RecordedMealConversionRepository(this.db);

  Future<List<RecordedMealConversionRequest>> missingForMeal(int mealId) async {
    final rows = await db
        .customSelect(
          'SELECT mi.id, mi.meal_id, mi.ingredient_id, mi.portion_id, '
          'i.name AS ingredient_name, p.name AS portion_name, ip.grams_per_portion '
          'FROM meal_ingredients mi JOIN ingredient i ON i.id = mi.ingredient_id '
          'JOIN portion p ON p.id = mi.portion_id '
          'LEFT JOIN ingredient_portions ip ON ip.ingredient_id = mi.ingredient_id '
          'AND ip.portion_id = mi.portion_id '
          'WHERE mi.meal_id = ? AND mi.grams_per_portion_used IS NULL '
          'AND i.is_reference = 0 ORDER BY mi.id',
          variables: [Variable.withInt(mealId)],
          readsFrom: {
            db.mealIngredients,
            db.ingredient,
            db.portion,
            db.ingredientPortions,
          },
        )
        .get();
    return [
      for (final row in rows)
        RecordedMealConversionRequest(
          entryId: row.read<int>('id'),
          mealId: row.read<int>('meal_id'),
          ingredientId: row.read<int>('ingredient_id'),
          portionId: row.read<int>('portion_id'),
          ingredientName: row.read<String>('ingredient_name'),
          portionName: row.read<String>('portion_name'),
          currentGrams: row.readNullable<double>('grams_per_portion'),
        ),
    ];
  }

  Future<void> confirm(
    Map<RecordedMealConversionRequest, double> reviewed,
  ) async {
    if (reviewed.values.any((value) => !value.isFinite || value <= 0)) {
      throw ArgumentError('A portion weight must be finite and positive');
    }
    await db.transaction(() async {
      for (final entry in reviewed.entries) {
        final request = entry.key;
        final changed =
            await (db.update(db.mealIngredients)..where(
                  (row) =>
                      row.id.equals(request.entryId) &
                      row.mealId.equals(request.mealId) &
                      row.ingredientId.equals(request.ingredientId) &
                      row.portionId.equals(request.portionId) &
                      row.gramsPerPortionUsed.isNull(),
                ))
                .write(
                  MealIngredientsCompanion(
                    gramsPerPortionUsed: Value(entry.value),
                  ),
                );
        if (changed != 1) {
          throw StateError(
            'The meal ingredient changed during conversion review',
          );
        }
      }
    });
  }
}

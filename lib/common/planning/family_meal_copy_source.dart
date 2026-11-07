import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/data/model/copied_meal_type.dart';
import '../meal/recorded_meal_conversion_unavailable.dart';
import 'family_meal_draft.dart';

/// Projects a mirrored meal into a new plan, never its execution state.
class FamilyMealCopySource {
  const FamilyMealCopySource(this.rows);
  final List<Map<String, dynamic>> rows;

  List<CopiedMealType> search(String query) => [
    for (final row in rows)
      if (row['kind'] == 'meals' && row['deleted'] != true)
        if ((row['payload'] as Map)['purpose'] != 'lowTreatment' &&
            ((row['payload'] as Map)['name'] as String).toLowerCase().contains(
              query.trim().toLowerCase(),
            ))
          CopiedMealFromMeal(
            id: (row['payload'] as Map)['id'] as int,
            name: (row['payload'] as Map)['name'] as String,
            date: DateTime.fromMillisecondsSinceEpoch(
              (row['payload'] as Map)['planned_at'] as int,
            ),
            copiedFromMealId: null,
            copiedFromTemplateId: null,
          ),
  ];

  List<MealIngredientsDraft> ingredients(int mealId) {
    final items = rows.where(
      (r) =>
          r['kind'] == 'mealIngredients' &&
          r['deleted'] != true &&
          (r['payload'] as Map)['meal_id'] == mealId,
    );
    final combined = <int, double>{};
    for (final row in items) {
      final p = row['payload'] as Map;
      final ingredient = rows
          .where(
            (r) =>
                r['kind'] == 'ingredients' &&
                r['deleted'] != true &&
                r['id'] == '${p['ingredient_id']}',
          )
          .firstOrNull;
      if (ingredient == null) throw RecordedMealConversionUnavailable();
      final reference = (ingredient['payload'] as Map)['is_reference'] == 1;
      final factor =
          (p['grams_per_portion_used'] as num?)?.toDouble() ??
          (reference
              ? 100.0
              : p['portion_id'] == null
              ? 1.0
              : null);
      if (factor == null || !factor.isFinite || factor <= 0) {
        throw RecordedMealConversionUnavailable();
      }
      final grams = (p['amount'] as num).toDouble() * factor;
      if (!grams.isFinite || grams <= 0) {
        throw RecordedMealConversionUnavailable();
      }
      final id = p['ingredient_id'] as int;
      combined[id] = (combined[id] ?? 0) + grams;
    }
    final initial = [
      for (final item in combined.entries)
        {'ingredientId': item.key, 'grams': item.value},
    ];
    if (initial.isEmpty) throw RecordedMealConversionUnavailable();
    return familyMealDraft(rows, {'ingredients': initial}).mealIngredients;
  }
}

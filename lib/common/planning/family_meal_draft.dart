import '../../features/ingredients/data/drafts/ingredient_draft.dart';
import '../../features/ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/portions/data/drafts/portion_draft.dart';
import '../family_sync/presentation/models/family_ingredient_view.dart';
import '../meal/meal_category.dart';

MealDraft familyMealDraft(
  List<Map<String, dynamic>> rows,
  Map<String, dynamic>? initial,
) {
  final ingredients = <MealIngredientsDraft>[];
  for (final raw in initial?['ingredients'] as List? ?? const []) {
    final item = raw as Map;
    final row = rows
        .where(
          (r) =>
              r['kind'] == 'ingredients' &&
              r['deleted'] != true &&
              r['id'] == '${item['ingredientId']}',
        )
        .firstOrNull;
    final ingredient = row == null
        ? IngredientDraft.draft(
            name: '${item['catalogId']}',
            carbsPer100g: 0,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 0,
            isReference: false,
          )
        : familyIngredientView(row).toDraft();
    if (row == null) {
      if (item['catalogId'] == null) {
        throw StateError('Child ingredient is unavailable');
      }
    }
    final factor = ingredient.isReference ? 100.0 : 1.0;
    ingredients.add(
      MealIngredientsDraft(
        ingredient: ingredient,
        catalogId: row == null ? item['catalogId'] as String? : null,
        catalogRevision: row == null
            ? item['catalogRevision'] as String?
            : null,
        catalogReviewed: row != null,
        ingredientPortion: IngredientPortionDraft(
          portion: const PortionSelection.empty(),
          amount: factor,
        ),
        recordedGramsPerAmount: factor,
        amount: (item['grams'] as num).toDouble() / factor,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      ),
    );
  }
  return MealDraft(
    name: initial?['name'] as String? ?? '',
    category:
        MealCategory.fromStorage(initial?['category'] as String?) ??
        MealCategory.lunch,
    mealIngredients: ingredients,
    status: 'planned',
    notes: initial?['notes'] as String?,
    plannedAt: DateTime.fromMillisecondsSinceEpoch(
      initial?['plannedAt'] as int? ??
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    ),
  );
}

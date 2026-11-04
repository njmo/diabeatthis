import 'package:drift/drift.dart';

import '../../../common/ingredient_catalog/ingredient_search_normalizer.dart';
import '../../../core/drift/database_impl.dart';
import '../domain/models/meal_photo_item.dart';
import '../domain/models/meal_photo_review_item.dart';
import 'meal_photo_reference_draft_factory.dart';

/// Shared by the save preview and the transactional writer.
Future<int?> findExistingPhotoReferenceId(
  DatabaseImpl db,
  MealPhotoReviewItem item,
) async {
  if (!item.validWeight || item.referenceNutrition == null) return null;
  final accepted = item.referenceAccepted ? item : item.acceptReference();
  final draft = const MealPhotoReferenceDraftFactory()(accepted);
  final scope =
      item.proposal.referenceScope == MealPhotoReferenceScope.wholeMeal
      ? 'whole_plate'
      : 'component';
  final existing = await db
      .customSelect(
        'SELECT i.id, i.name FROM ingredient i '
        'JOIN ingredient_origin o ON o.ingredient_id = i.id '
        "WHERE o.creation_method = 'photo_reference' AND o.reference_scope = ? "
        'AND i.is_reference = 0 AND i.carbs_label_mode = ? '
        'AND ABS(i.carbs_per_100g - ?) < 0.00000001 '
        'AND ABS(i.fiber_per_100g - ?) < 0.00000001 '
        'AND ABS(i.fat_per_100g - ?) < 0.00000001 '
        'AND ABS(i.protein_per_100g - ?) < 0.00000001 ORDER BY i.id',
        variables: [
          Variable(scope),
          Variable(draft.carbsLabelMode.name),
          Variable(draft.carbsPer100g),
          Variable(draft.fiberPer100g),
          Variable(draft.fatPer100g),
          Variable(draft.proteinPer100g),
        ],
      )
      .get();
  for (final row in existing) {
    if (normalizeIngredientSearch(row.read<String>('name')) ==
        normalizeIngredientSearch(draft.name)) {
      return row.read<int>('id');
    }
  }
  return null;
}

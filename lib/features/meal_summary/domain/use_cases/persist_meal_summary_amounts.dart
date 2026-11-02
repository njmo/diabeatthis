import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../presentation/models/meal_summary_draft.dart';
import 'add_meal_extra_item_use_case.dart';

Future<void> persistMealSummaryAmounts(Ref ref, MealSummaryDraft draft) async {
  final db = ref.read(databaseProvider);
  for (final item in draft.itemsById.values) {
    await db.mealIngredientsDao.updateMealIngredientConsumed(
      item.mealIngredientId,
      item.consumedAmount,
      item.consumedConfidence,
    );
  }
  for (final item in draft.extraItems) {
    await ref
        .read(addMealExtraItemUseCaseProvider)
        .call(mealId: draft.mealId, mealIngredient: item, statusAfterAdd: null);
  }
}

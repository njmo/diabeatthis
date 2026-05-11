import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';

final addMealExtraItemUseCaseProvider = Provider<AddMealExtraItemUseCase>((
  ref,
) {
  return AddMealExtraItemUseCase(ref: ref);
});

class AddMealExtraItemUseCase with Logging {
  AddMealExtraItemUseCase({required this.ref});

  final Ref ref;

  Future<void> call({
    required int mealId,
    required MealIngredientsDraft mealIngredient,
    String? statusAfterAdd = 'eating-extra',
  }) async {
    final db = ref.read(databaseProvider);

    await db.transaction(() async {
      final ingredient = await ref.read(
        insertIngredientProvider(mealIngredient.ingredient).future,
      );
      logI('Added extra ingredient ${ingredient.name}');

      final portion = await ref.read(
        insertPortionProvider(mealIngredient.ingredientPortion.portion).future,
      );

      await ref.read(
        insertIngredientPortionProvider(
          ingredient,
          portion,
          mealIngredient.ingredientPortion.amount,
        ).future,
      );

      await ref.read(
        insertExtraMealIngredientProvider(
          ingredient,
          mealId,
          portion,
          mealIngredient.amount,
          mealIngredient.quantityConfidence,
        ).future,
      );

      if (statusAfterAdd != null) {
        await ref.read(updateMealByIdProvider(mealId, statusAfterAdd).future);
      }
    });
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';

part 'meal_add_provider.g.dart';

enum MealStatus
{
  error,
  inProgress,
  added
}

@Riverpod(keepAlive: true)
class MealAddNotifier extends _$MealAddNotifier with Logging {
  @override
  void build() {
  }

  Future<Meal> addMeal(MealDraft updatedDraft) async
  {
    final mealIngredientDrafts = ref.read(
      mealDraftIngredientsProvider,
    );

    logI(
      'Adding ${updatedDraft.name}');
    final meal = await ref.read(
      insertMealProvider(updatedDraft).future,
    );
    logI("Added ${meal.name}");
    for (final mealIngredient in mealIngredientDrafts) {
      final ingredient = await ref.read(
        insertIngredientProvider(
          mealIngredient.ingredient,
        ).future,
      );
      logI("Added ${(ingredient).name}");
      final portion = await ref.read(
        insertPortionProvider(
          mealIngredient.ingredientPortion.portion,
        ).future,
      );

      logI("Added ${portion?.name ?? 'no portion'}");
      logI("Adding ingredient portion relation");
      await ref.read(
        insertIngredientPortionProvider(
          ingredient,
          portion,
          mealIngredient.ingredientPortion.amount,
        ).future,
      );
      await ref.read(
        insertMealIngredientProvider(
          ingredient,
          meal,
          portion,
          mealIngredient.amount,
          mealIngredient.quantityConfidence,
        ).future,
      );
      logI("Added meal ingredient");
    }
    return meal;
  }

}
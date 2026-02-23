import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';

part 'meal_add_provider.g.dart';

enum MealStatus
{
  error,
  inProgress,
  added
}

@riverpod
class MealAddNotifier extends _$MealAddNotifier {
  @override
  void build() {
  }

  Future<Meal> addMeal(MealDraft updatedDraft) async
  {
    final mealIngredientDrafts = ref.read(
      mealDraftIngredientsProvider,
    );

    print(
      'Adding ${updatedDraft.name} with carbs ${updatedDraft.carbs}');
    final meal = await ref.read(
      insertMealProvider(updatedDraft).future,
    );
    print("Added ${meal.name}");
    for (final mealIngredient in mealIngredientDrafts) {
      final ingredient = await ref.read(
        insertIngredientProvider(
          mealIngredient.ingredient,
        ).future,
      );
      print("Added ${(ingredient).name}");
      final portion = await ref.read(
        insertPortionProvider(
          mealIngredient.ingredientPortion.portion,
        ).future,
      );

      print("Added ${portion?.name ?? 'no portion'}");
      print("Adding ingredient portion relation");
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
      print("Added meal ingredient");
    }
    return meal;
  }

}
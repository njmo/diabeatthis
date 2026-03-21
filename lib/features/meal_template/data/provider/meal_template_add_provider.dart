import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/meal_template.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../drafts/template_meal_draft.dart';
import 'meal_template_database_provider.dart';
import 'meal_template_ingredients_list_provider.dart';

part 'meal_template_add_provider.g.dart';

enum MealStatus
{
  error,
  inProgress,
  added
}

@riverpod
class MealTemplateAddNotifier extends _$MealTemplateAddNotifier {
  @override
  void build() {
  }

  Future<MealTemplate> addMealTemplate(MealTemplateDraft updatedDraft) async
  {
    final mealTemplateIngredientDrafts = ref.read(
      mealTemplateDraftIngredientsProvider,
    );

    print(
        'Adding ${updatedDraft.name}');
    final meal = await ref.read(
      insertMealTemplateProvider(updatedDraft).future,
    );
    print("Added ${meal.name}");
    for (final mealIngredient in mealTemplateIngredientDrafts) {
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
        insertMealTemplateIngredientProvider(
          ingredient,
          meal,
          portion,
          mealIngredient.defaultAmount,
          mealIngredient.quantityConfidence,
          mealIngredient.isOptional,
        ).future,
      );
      print("Added meal ingredient");
    }
    return meal;
  }

}
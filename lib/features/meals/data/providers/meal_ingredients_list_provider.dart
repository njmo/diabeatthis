import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../portions/data/mappers/portion_draft_mapper.dart';
import '../drafts/meal_draft.dart';
import 'meal_draft_provider.dart';

part 'meal_ingredients_list_provider.g.dart';

@riverpod
List<MealIngredientsDraft> mealDraftIngredients(Ref ref) {
  return ref.watch(mealDraftProvider.select((h) => h.mealIngredients));
}

@riverpod
Future<int> calculatedCarbs(Ref ref) async {
  final ingredients = ref.watch(mealDraftIngredientsProvider);
  var carbs = 0;

  for (final mi in ingredients) {
    var portionAmount = mi.ingredientPortion.amount;

    if (portionAmount == 0) {
      final fetched = await ref.read(
        getAmountForPortionIngredientProvider(
          mi.ingredient.toDomain(),
          mi.ingredientPortion.portion.toDomain(),
        ).future,
      );
      portionAmount = fetched ?? 0;
    }

    final grams = mi.amount * portionAmount;
    final carbHere = (mi.ingredient.carbsPer100g * grams / 100).round();
    carbs += carbHere;
  }

  return carbs;
}

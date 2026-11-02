import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drafts/meal_draft.dart';
import 'resolve_meal_ingredient_grams_use_case.dart';

class FindDominantMealIngredientsUseCase {
  const FindDominantMealIngredientsUseCase(this.ref);
  final Ref ref;

  Future<List<String>> call(List<MealIngredientsDraft> ingredients) async {
    final weighted = <({String name, double grams, int index})>[];
    for (var index = 0; index < ingredients.length; index++) {
      final ingredient = ingredients[index];
      final name = ingredient.ingredient.name.trim();
      if (name.isEmpty || ingredient.amount <= 0) continue;
      final grams = await ResolveMealIngredientGramsUseCase(
        ref,
      ).call(ingredient);
      weighted.add((
        name: name,
        grams: grams.isFinite && grams > 0 ? grams : 0,
        index: index,
      ));
    }
    weighted.sort((a, b) {
      final weight = b.grams.compareTo(a.grams);
      return weight == 0 ? a.index.compareTo(b.index) : weight;
    });
    final names = <String>[];
    final seen = <String>{};
    for (final ingredient in weighted) {
      if (seen.add(ingredient.name.toLowerCase())) names.add(ingredient.name);
      if (names.length == 2) break;
    }
    return names;
  }
}

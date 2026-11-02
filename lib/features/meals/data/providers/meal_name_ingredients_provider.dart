import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/use_cases/find_dominant_meal_ingredients_use_case.dart';
import 'meal_ingredients_list_provider.dart';

final mealNameIngredientsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final ingredients = ref.watch(mealDraftIngredientsProvider);
  return FindDominantMealIngredientsUseCase(ref).call(ingredients);
});

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../controllers/low_treatment_context_controller.dart';

part 'low_treatment_context_providers.g.dart';

@riverpod
Future<({int carbsTotal, int extendedCarbsTotal})> lowTreatmentCarbsSummary(
  Ref ref,
) async {
  final ingredients = ref
      .watch(lowTreatmentContextControllerProvider)
      .mealIngredients;
  final macros = await calculateMealIngredientsMacronutrients(ref, ingredients);

  return (
    carbsTotal: macros.carbsTotal,
    extendedCarbsTotal: macros.extendedCarbsTotal,
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/meal_macro_summary.dart';
import '../domain/use_cases/calculate_meal_draft_nutrition_use_case.dart';
import '../domain/use_cases/resolve_meal_ingredient_grams_use_case.dart';
import 'meal_draft_provider.dart';

final mealDraftMacroSummaryProvider =
    FutureProvider.autoDispose<MealMacroSummary>((ref) {
      final ingredients = ref.watch(
        mealDraftProvider.select((draft) => draft.mealIngredients),
      );
      return CalculateMealDraftNutritionUseCase(
        resolveGrams: ResolveMealIngredientGramsUseCase(ref).call,
      )(ingredients);
    });

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../data/models/meal_summary_data.dart';
import '../../data/models/meal_summary_item.dart';
import '../../data/models/meal_summary_portion.dart';

part 'load_meal_summary_data_use_case.g.dart';

@riverpod
LoadMealSummaryDataUseCase loadMealSummaryDataUseCase(Ref ref) {
  return LoadMealSummaryDataUseCase(ref: ref);
}

class LoadMealSummaryDataUseCase {
  final Ref ref;

  LoadMealSummaryDataUseCase({required this.ref});

  Future<MealSummaryData> call(int mealId) async {
    final mealIngredients = await ref.read(
      getMealIngredientsDraftForMealProvider(mealId).future,
    );
    final items = mealIngredients.map((mealIngredient) {
      return MealSummaryItem(
        name: mealIngredient.ingredient.name,
        id: mealIngredient.mealIngredientId!,
        isReference: mealIngredient.ingredient.isReference,
        portion: _mapPortion(mealIngredient.ingredientPortion),
        plannedAmount: mealIngredient.amount.toDouble(),
      );
    }).toList();
    return MealSummaryData(mealId: mealId, items: items);
  }

  MealSummaryPortion? _mapPortion(IngredientPortionDraft ingredientPortion) {
    final portion = ingredientPortion.portion;
    return portion.map(
      empty: (_) => null,
      existing: (e) => MealSummaryPortion(
        name: e.name,
        hint: e.unitHint,
        amountInPortion: ingredientPortion.amount.toDouble(),
      ),
      draft: (e) => MealSummaryPortion(
        name: e.name,
        hint: e.unitHint,
        amountInPortion: ingredientPortion.amount.toDouble(),
      ),
    );
  }
}

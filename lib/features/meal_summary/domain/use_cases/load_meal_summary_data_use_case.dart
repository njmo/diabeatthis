import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
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
    final meal = await ref.read(getMealByIdProvider(mealId).future);
    final mealIngredients = await ref.read(
      getMealIngredientsDraftForMealProvider(mealId).future,
    );
    final items = mealIngredients.map((mealIngredient) {
      final plannedAmount = _plannedAmount(mealIngredient);
      final reportedAmount = mealIngredient.consumedAmount ?? plannedAmount;

      return MealSummaryItem(
        name: mealIngredient.ingredient.name,
        id: mealIngredient.mealIngredientId!,
        isReference: mealIngredient.ingredient.isReference,
        portion: _mapPortion(mealIngredient.ingredientPortion),
        plannedAmount: plannedAmount,
        reportedAmount: reportedAmount,
        consumedAmount: reportedAmount,
        consumedConfidence: mealIngredient.consumedConfidence ?? 1.0,
        netCarbsPerAmount: _netCarbsPerAmount(mealIngredient),
      );
    }).toList();
    return MealSummaryData(
      mealId: mealId,
      mealStatus: meal?.status,
      items: items,
    );
  }

  double _plannedAmount(MealIngredientsDraft mealIngredient) {
    if (mealIngredient.entryType == 'extra') {
      return mealIngredient.consumedAmount ?? mealIngredient.amount.toDouble();
    }

    return mealIngredient.amount.toDouble();
  }

  double _netCarbsPerAmount(MealIngredientsDraft mealIngredient) {
    final netCarbsPer100g =
        mealIngredient.ingredient.carbsPer100g -
        mealIngredient.ingredient.fiberPer100g;
    final safeNetCarbsPer100g = netCarbsPer100g < 0
        ? 0.0
        : netCarbsPer100g.toDouble();

    if (mealIngredient.ingredient.isReference) {
      return safeNetCarbsPer100g;
    }

    final gramsPerAmount = mealIngredient.ingredientPortion.portion.map(
      empty: (_) => 1.0,
      existing: (_) => mealIngredient.ingredientPortion.amount.toDouble(),
      draft: (_) => mealIngredient.ingredientPortion.amount.toDouble(),
    );

    return gramsPerAmount * safeNetCarbsPer100g / 100;
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

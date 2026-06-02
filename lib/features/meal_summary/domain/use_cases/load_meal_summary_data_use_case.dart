import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../data/models/meal_summary_data.dart';
import '../../data/models/meal_summary_item.dart';
import '../../data/models/meal_summary_portion.dart';

part 'load_meal_summary_data_use_case.g.dart';

@Riverpod(keepAlive: true)
LoadMealSummaryDataUseCase loadMealSummaryDataUseCase(Ref ref) {
  return LoadMealSummaryDataUseCase(ref: ref);
}

class LoadMealSummaryDataUseCase {
  final Ref ref;

  LoadMealSummaryDataUseCase({required this.ref});

  Future<MealSummaryData> call(int mealId) async {
    final mealFuture = ref.read(getMealByIdProvider(mealId).future);
    final mealIngredientsFuture = ref.read(
      getMealIngredientsDraftForMealProvider(mealId).future,
    );

    final meal = await mealFuture;
    final mealIngredients = await mealIngredientsFuture;

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
    if (mealIngredient.ingredient.isReference) {
      return calculateNetCarbs(
        carbs: mealIngredient.ingredient.carbsPer100g,
        fiber: mealIngredient.ingredient.fiberPer100g,
        labelMode: mealIngredient.ingredient.carbsLabelMode,
      );
    }

    final gramsPerAmount = mealIngredient.ingredientPortion.portion.map(
      empty: (_) => 1.0,
      existing: (_) => mealIngredient.ingredientPortion.amount.toDouble(),
      draft: (_) => mealIngredient.ingredientPortion.amount.toDouble(),
    );

    return calculateNetCarbs(
      carbs: gramsPerAmount * mealIngredient.ingredient.carbsPer100g / 100,
      fiber: gramsPerAmount * mealIngredient.ingredient.fiberPer100g / 100,
      labelMode: mealIngredient.ingredient.carbsLabelMode,
    );
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

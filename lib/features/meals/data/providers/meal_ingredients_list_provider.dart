import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/nutrition/stable_macro_ceil.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/mappers/portion_draft_mapper.dart';
import '../domain/use_cases/resolve_meal_ingredient_grams_use_case.dart';
import '../drafts/meal_draft.dart';
import 'meal_draft_provider.dart';

part 'meal_ingredients_list_provider.g.dart';
part 'meal_ingredients_list_provider.freezed.dart';

@riverpod
List<MealIngredientsDraft> mealDraftIngredients(Ref ref) {
  return ref.watch(mealDraftProvider.select((h) => h.mealIngredients));
}

@riverpod
Future<List<MealIngredientsDraft>> getMealIngredientsDraftForMeal(
  Ref ref,
  int mealId,
) async {
  final db = ref.read(databaseProvider);
  final mealIngredients = await db.mealIngredientsDao.getMealIngredientsForMeal(
    mealId,
  );
  final list = <MealIngredientsDraft>[];
  for (final mealIngredient in mealIngredients) {
    final ingredient = await db.ingredientDao.getIngredientById(
      mealIngredient.ingredientId,
    );
    if (ingredient.isReference == 1) {
      list.add(
        MealIngredientsDraft(
          mealIngredientId: mealIngredient.id,
          ingredient: ingredient.toDomain().toDraft(),
          ingredientPortion: IngredientPortionDraft(
            portion: PortionSelection.empty(),
            amount: 100,
          ),
          amount: mealIngredient.amount,
          quantityConfidence: mealIngredient.quantityConfidence,
          nutritionConfidenceOverride:
              mealIngredient.nutritionConfidenceOverride,
          entryType: mealIngredient.entryType,
          consumedAmount: mealIngredient.consumedAmount,
          consumedConfidence: mealIngredient.consumedConfidence,
        ),
      );
      continue;
    }
    if (mealIngredient.portionId != null &&
        mealIngredient.gramsPerPortionUsed == null) {
      throw StateError('The recorded meal portion conversion is unavailable');
    }
    IngredientPortionDraft ingredientPortion;
    final portionId = mealIngredient.portionId;
    if (portionId != null) {
      final gramsPerPortion = mealIngredient.gramsPerPortionUsed!;
      final portion = await db.portionDao.getPortionById(portionId);
      ingredientPortion = IngredientPortionDraft(
        portion: portion.toSelection(),
        amount: gramsPerPortion,
      );
    } else {
      ingredientPortion = IngredientPortionDraft(
        portion: PortionSelection.empty(),
        amount: 1,
      );
    }

    list.add(
      MealIngredientsDraft(
        mealIngredientId: mealIngredient.id,
        recordedGramsPerAmount:
            mealIngredient.portionId == null &&
                mealIngredient.gramsPerPortionUsed != null &&
                mealIngredient.gramsPerPortionUsed != 1
            ? mealIngredient.gramsPerPortionUsed
            : null,
        ingredient: ingredient.toDomain().toDraft(),
        ingredientPortion: ingredientPortion,
        amount: mealIngredient.amount,
        quantityConfidence: mealIngredient.quantityConfidence,
        nutritionConfidenceOverride: mealIngredient.nutritionConfidenceOverride,
        entryType: mealIngredient.entryType,
        consumedAmount: mealIngredient.consumedAmount,
        consumedConfidence: mealIngredient.consumedConfidence,
      ),
    );
  }
  return list;
}

@riverpod
Future<MealMacroSummary?> mealMacronutrientsConsumedSummary(
  Ref ref,
  int mealId,
) async {
  final db = ref.read(databaseProvider);
  final mealStatus = await db.ingredientDao.totalsForMealConsumed(mealId);
  return mealStatus;
}

@riverpod
Future<MealMacroSummary?> mealMacronutrientsSummary(Ref ref, int mealId) async {
  final db = ref.read(databaseProvider);
  final mealStatus = await db.ingredientDao.totalsForMeal(mealId);
  return mealStatus;
}

@freezed
abstract class Macronutrients with _$Macronutrients {
  const factory Macronutrients({
    required int carbsTotal,
    required int fatTotal,
    required int fiberTotal,
    required int proteinTotal,
    required int netCarbsTotal,
    int? extendedCarbsFromRawTotals,
  }) = _Macronutrients;
}

extension MacronutrientsExtendedCarbs on Macronutrients {
  int get extendedCarbsTotal {
    return extendedCarbsFromRawTotals ??
        const WbtExtendedCarbsCalculator()
            .calculateFromMacros(
              fatGrams: fatTotal.toDouble(),
              proteinGrams: proteinTotal.toDouble(),
            )
            .grams;
  }
}

@riverpod
Future<Macronutrients> calculatedMacronutrients(Ref ref) async {
  final ingredients = ref.watch(mealDraftIngredientsProvider);
  return calculateMealIngredientsMacronutrients(ref, ingredients);
}

Future<Macronutrients> calculateMealIngredientsMacronutrients(
  Ref ref,
  List<MealIngredientsDraft> ingredients,
) async {
  var carbsTotal = 0.0;
  var fatTotal = 0.0;
  var fiberTotal = 0.0;
  var proteinTotal = 0.0;
  var netCarbsTotal = 0.0;

  for (final mi in ingredients) {
    final grams = await ResolveMealIngredientGramsUseCase(ref).call(mi);
    carbsTotal += (mi.ingredient.carbsPer100g * grams / 100);
    fatTotal += (mi.ingredient.fatPer100g * grams / 100);
    fiberTotal += (mi.ingredient.fiberPer100g * grams / 100);
    proteinTotal += (mi.ingredient.proteinPer100g * grams / 100);
    netCarbsTotal += calculateNetCarbs(
      carbs: mi.ingredient.carbsPer100g * grams / 100,
      fiber: mi.ingredient.fiberPer100g * grams / 100,
      labelMode: mi.ingredient.carbsLabelMode,
    );
  }

  return Macronutrients(
    carbsTotal: carbsTotal.ceilMacro(),
    fatTotal: fatTotal.ceilMacro(),
    fiberTotal: fiberTotal.ceilMacro(),
    proteinTotal: proteinTotal.ceilMacro(),
    netCarbsTotal: netCarbsTotal.ceilMacro(),
    extendedCarbsFromRawTotals: const WbtExtendedCarbsCalculator()
        .calculateFromMacros(fatGrams: fatTotal, proteinGrams: proteinTotal)
        .grams,
  );
}

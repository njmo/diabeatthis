import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/mappers/portion_draft_mapper.dart';
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
          entryType: mealIngredient.entryType,
          consumedAmount: mealIngredient.consumedAmount,
          consumedConfidence: mealIngredient.consumedConfidence,
        ),
      );
      continue;
    }
    IngredientPortionDraft ingredientPortion;
    final portionId = mealIngredient.portionId;
    if (portionId != null) {
      final gramsPerPortion = await db.portionDao.getGramsPerPortion(
        ingredient.id,
        portionId,
      );
      final portion = await db.portionDao.getPortionById(portionId);
      ingredientPortion = IngredientPortionDraft(
        portion: portion.toSelection(),
        amount: gramsPerPortion ?? 1,
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
        ingredient: ingredient.toDomain().toDraft(),
        ingredientPortion: ingredientPortion,
        amount: mealIngredient.amount,
        quantityConfidence: mealIngredient.quantityConfidence,
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
  }) = _Macronutrients;
}

extension MacronutrientsExtendedCarbs on Macronutrients {
  int get extendedCarbsTotal {
    return const WbtExtendedCarbsCalculator()
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
  var carbsTotal = 0;
  var fatTotal = 0;
  var fiberTotal = 0;
  var proteinTotal = 0;
  var netCarbsTotal = 0;

  for (final mi in ingredients) {
    final isReference = mi.ingredient.isReference;
    var portionAmount = mi.ingredientPortion.amount;
    final isEmpty = mi.ingredientPortion.portion.maybeMap(
      orElse: () => false,
      empty: (empty) => true,
    );

    if (!isEmpty && portionAmount == 0) {
      final ingredientDomain = mi.ingredient.toDomain();
      final portionDomain = mi.ingredientPortion.portion.toDomain();

      final fetched = await ref.read(
        getAmountForPortionIngredientProvider(
          ingredientDomain,
          portionDomain,
        ).future,
      );

      portionAmount = fetched ?? 0;
    }
    final gramsPerPortion =
        resolveIngredientGramsPerPortion(
          usesGramAmount: isEmpty && !isReference,
          isReference: isEmpty && isReference,
          portionGrams: portionAmount,
          // Keep aggregation's resolved weight, including legacy zero/negative values.
          storedGramsPerPortion: portionAmount,
        ) ??
        0;
    final grams = mi.amount * gramsPerPortion;
    carbsTotal += (mi.ingredient.carbsPer100g * grams / 100).ceil();
    fatTotal += (mi.ingredient.fatPer100g * grams / 100).ceil();
    fiberTotal += (mi.ingredient.fiberPer100g * grams / 100).ceil();
    proteinTotal += (mi.ingredient.proteinPer100g * grams / 100).ceil();
    netCarbsTotal += calculateNetCarbs(
      carbs: mi.ingredient.carbsPer100g * grams / 100,
      fiber: mi.ingredient.fiberPer100g * grams / 100,
      labelMode: mi.ingredient.carbsLabelMode,
    ).ceil();
  }

  return Macronutrients(
    carbsTotal: carbsTotal,
    fatTotal: fatTotal,
    fiberTotal: fiberTotal,
    proteinTotal: proteinTotal,
    netCarbsTotal: netCarbsTotal,
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/mappers/portion_draft_mapper.dart';
import '../drafts/template_meal_draft.dart';
import 'meal_template_draft_provider.dart';

part 'meal_template_ingredients_list_provider.g.dart';

@riverpod
List<MealTemplateIngredientsDraft> mealTemplateDraftIngredients(Ref ref) {
  return ref.watch(mealTemplateDraftProvider.select((h) => h.mealIngredients));
}

@riverpod
Future<List<MealIngredientsDraft>> getMealIngredientsDraftForMealTemplate(
  Ref ref,
  int mealTemplateId,
) async {
  final db = ref.read(databaseProvider);
  final mealIngredients = await db.mealTemplateIngredientsDao
      .getMealTemplateIngredientsForMeal(mealTemplateId);
  final list = <MealIngredientsDraft>[];
  for (final mealIngredient in mealIngredients) {
    final ingredient = await db.ingredientDao.getIngredientById(
      mealIngredient.ingredientId,
    );
    if (ingredient.isReference == 1) {
      list.add(
        MealIngredientsDraft(
          ingredient: ingredient.toDomain().toDraft(),
          ingredientPortion: IngredientPortionDraft(
            portion: PortionSelection.empty(),
            amount: 100,
          ),
          amount: mealIngredient.defaultAmount ?? 0,
          quantityConfidence: mealIngredient.quantityConfidence,
          entryType: 'planned',
          consumedAmount: null,
          consumedConfidence: null,
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
        ingredient: ingredient.toDomain().toDraft(),
        ingredientPortion: ingredientPortion,
        amount: mealIngredient.defaultAmount ?? 0,
        quantityConfidence: mealIngredient.quantityConfidence,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      ),
    );
  }
  return list;
}

@riverpod
Future<Macronutrients> calculatedTemplateMacronutrients(Ref ref) async {
  final ingredients = ref.watch(mealTemplateDraftIngredientsProvider);
  var carbsTotal = 0;
  var fatTotal = 0;
  var fiberTotal = 0;
  var proteinTotal = 0;

  for (final mi in ingredients) {
    final isReference = mi.ingredient.isReference;
    var portionAmount = mi.ingredientPortion.amount;
    final isEmpty = mi.ingredientPortion.portion.maybeMap(
      orElse: () => false,
      empty: (empty) => true,
    );

    if (isEmpty) {
      if (isReference) {
        portionAmount = 100;
      } else {
        portionAmount = 1;
      }
    } else if (portionAmount == 0) {
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
    final grams = mi.defaultAmount * portionAmount;
    carbsTotal += (mi.ingredient.carbsPer100g * grams / 100).round();
    fatTotal += (mi.ingredient.fatPer100g * grams / 100).round();
    fiberTotal += (mi.ingredient.fiberPer100g * grams / 100).round();
    proteinTotal += (mi.ingredient.proteinPer100g * grams / 100).round();
  }

  return Macronutrients(
    carbsTotal: carbsTotal,
    fatTotal: fatTotal,
    fiberTotal: fiberTotal,
    proteinTotal: proteinTotal,
  );
}

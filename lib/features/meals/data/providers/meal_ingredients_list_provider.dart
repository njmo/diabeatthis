import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/drift/dao/ingredient_dao.dart';
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
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
Future<MealSummary?> mealMacronutrientsSummary(Ref ref, int mealId) async {
  final db = ref.watch(databaseProvider);
  return await db.ingredientDao.totalsForMeal(mealId);
}

@freezed
abstract class Macronutrients with _$Macronutrients {
  @override
  const factory Macronutrients({
    required int carbsTotal,
    required int fatTotal,
    required int fiberTotal,
    required int proteinTotal,
  }) = _Macronutrients;
}

@riverpod
Future<Macronutrients> calculatedMacronutrients(Ref ref) async {
  final ingredients = ref.watch(mealDraftIngredientsProvider);
  var carbsTotal = 0;
  var fatTotal = 0;
  var fiberTotal = 0;
  var proteinTotal = 0;

  for (final mi in ingredients) {
    var portionAmount = mi.ingredientPortion.amount;
    final isEmpty = mi.ingredientPortion.portion.maybeMap(
      orElse: () => false,
      empty: (empty) => true,
    );

    if (isEmpty) {
      portionAmount = 1;
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
    final grams = mi.amount * portionAmount;
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

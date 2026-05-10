import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/providers/database_provider.dart';
import '../../models/ingredient_details_data.dart';
import '../../models/ingredient_portion_data.dart';
import '../../models/ingredient_usage_data.dart';

part 'load_ingredient_details_use_case.g.dart';

@Riverpod(keepAlive: true)
LoadIngredientDetailsUseCase loadIngredientDetailsUseCase(Ref ref) {
  return LoadIngredientDetailsUseCase(ref: ref);
}

class LoadIngredientDetailsUseCase {
  final Ref ref;

  LoadIngredientDetailsUseCase({required this.ref});

  Future<IngredientDetailsData> call(int ingredientId) async {
    final db = ref.read(databaseProvider);
    final ingredient = await db.ingredientDao.getIngredientById(ingredientId);
    final portions = await db.portionDao.getPortionsForIngredientId(
      ingredientId,
    );
    final meals = await db.mealDao.getMealsForIngredient(ingredientId);

    final ingredientUsage = meals.map((meal) {
      return IngredientUsageData(
        mealId: meal.id,
        name: meal.name,
        description: '',
        plannedAt: DateTime.fromMillisecondsSinceEpoch(meal.plannedAt),
        status: meal.status,
      );
    }).toList();

    final portionsData = await Future.wait(
      portions.map((portion) async {
        final grams = await db.portionDao.getGramsPerPortion(
          ingredientId,
          portion.id,
        );
        return IngredientPortionData(
          portionId: portion.id,
          name: portion.name,
          unitHint: portion.unitHint,
          gramsPerPortion: grams ?? 0,
        );
      }),
    );

    final ingredientData = Ingredient(
      id: ingredient.id,
      name: ingredient.name,
      carbsPer100g: ingredient.carbsPer100g,
      fatPer100g: ingredient.fatPer100g,
      fiberPer100g: ingredient.fiberPer100g,
      proteinPer100g: ingredient.proteinPer100g,
      nutritionConfidence: ingredient.nutritionConfidence,
      isReference: ingredient.isReference == 1,
      netKcalPer100g: ingredient.netKcalPer100g,
      kcalPer100g: ingredient.kcalPer100g,
      wbtKcalPer100g: ingredient.wbtKcalPer100g,
      ig: ingredient.ig,
      preparation: '',
      brand: ingredient.brand,
    );

    return IngredientDetailsData(
      ingredient: ingredientData,
      portions: portionsData,
      usages: ingredientUsage,
    );
  }
}

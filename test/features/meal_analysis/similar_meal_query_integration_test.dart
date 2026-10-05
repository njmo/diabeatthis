import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/meal_analysis/data/providers/find_similar_meals_provider.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_query.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/find_similar_meals_use_case.dart';
import 'package:diabeatthis/features/meals/data/mappers/similar_meal_query_mapper.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = SimilarMealQueryMapper();
  final at = DateTime(2026, 9, 15, 12);

  test('mapper preserves planned search inputs and excludes add-ons', () {
    final query = mapper.map(
      _details(
        at: at,
        planned: _snapshot('planned'),
        ingredients: [
          _ingredient(id: 10, plannedGrams: 100, consumedGrams: 80),
          _ingredient(
            id: 20,
            plannedGrams: 30,
            consumedGrams: 15,
            entryType: 'extra',
          ),
        ],
      ),
    );

    expect(query, isNotNull);
    expect(query!.mealId, 7);
    expect(query.asOf, at);
    expect(query.target.netCarbsGrams, 30);
    expect(query.composition!.grams, {10: 100});
  });

  test('mapper uses consumed amounts when a consumed snapshot exists', () {
    final query = mapper.map(
      _details(
        at: at,
        planned: _snapshot('planned'),
        consumed: _snapshot('consumed'),
        ingredients: [
          _ingredient(id: 10, plannedGrams: 100, consumedGrams: 80),
          _ingredient(
            id: 20,
            plannedGrams: 0,
            consumedGrams: 15,
            entryType: 'extra',
          ),
        ],
      ),
    )!;

    expect(query.composition!.grams, {10: 80, 20: 15});
  });

  test('shared use case provider accepts the mapped domain query', () async {
    late int mealId;
    late DateTime cutoff;
    final useCase = FindSimilarMealsUseCase(
      loadMeals: (start, end, excluded) async {
        mealId = excluded!;
        cutoff = end;
        return [];
      },
    );
    final container = ProviderContainer(
      overrides: [findSimilarMealsUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);
    final query = SimilarMealQuery(
      mealId: 7,
      asOf: at,
      target: MealMacroSummary(
        carbsGrams: 30,
        netCarbsGrams: 30,
        proteinGrams: 15,
        fatGrams: 10,
        fiberGrams: 0,
        totalGrams: 155,
      ),
    );

    final result = await container.read(findSimilarMealsUseCaseProvider)(
      mealId: query.mealId,
      asOf: query.asOf,
      target: query.target,
      composition: query.composition,
    );

    expect(mealId, 7);
    expect(cutoff, at);
    expect(result.target, same(query.target));
  });
}

MealDetailsData _details({
  required DateTime at,
  required MealSnapshotDetailsData? planned,
  MealSnapshotDetailsData? consumed,
  List<MealIngredientDetailsData> ingredients = const [],
}) {
  return MealDetailsData(
    meal: MealRecordData(
      id: 7,
      name: 'Meal',
      status: 'planned',
      plannedAt: at,
      summarizedAt: null,
      mealTemplateId: null,
      basedOnMealId: null,
      notes: null,
      createdAt: at,
      updatedAt: at,
      isSynced: false,
    ),
    advisorDecision: null,
    ingredients: ingredients,
    plannedSnapshot: planned,
    consumedSnapshot: consumed,
    statusHistory: const [],
  );
}

MealSnapshotDetailsData _snapshot(String type) {
  final at = DateTime(2026, 9, 15, 11);
  return MealSnapshotDetailsData(
    id: type == 'planned' ? 1 : 2,
    mealId: 7,
    snapshotType: type,
    totalGrams: 155,
    totalCarbsG: 35,
    totalFiberG: 5,
    totalNetCarbsG: 30,
    totalFatG: 10,
    totalProteinG: 15,
    totalCaloriesKcal: 270,
    ingredientsCount: 2,
    avgQuantityConfidence: null,
    minQuantityConfidence: null,
    carbWeightedQuantityConfidence: null,
    wbtWeightedQuantityConfidence: null,
    carbWeightedNutritionConfidence: null,
    wbtWeightedNutritionConfidence: null,
    carbWeightedEffectiveConfidence: null,
    wbtWeightedEffectiveConfidence: null,
    createdAt: at,
    updatedAt: at,
    isSynced: false,
  );
}

MealIngredientDetailsData _ingredient({
  required int id,
  required double plannedGrams,
  required double consumedGrams,
  String entryType = 'planned',
}) {
  const nutrition = IngredientNutritionData(
    carbsPer100g: 20,
    fatPer100g: 5,
    fiberPer100g: 2,
    proteinPer100g: 10,
    carbsLabelMode: CarbsLabelMode.eu,
    nutritionConfidence: 1,
    effectiveAt: null,
  );
  final at = DateTime(2026, 9, 15, 11);
  return MealIngredientDetailsData(
    mealIngredientId: id,
    ingredientId: id,
    ingredientName: 'Ingredient $id',
    entryType: entryType,
    portionLabel: 'g',
    plannedAmount: plannedGrams,
    consumedAmount: consumedGrams,
    quantityConfidence: 1,
    consumedConfidence: 1,
    plannedTotalGrams: plannedGrams,
    consumedTotalGrams: consumedGrams,
    prepMethod: null,
    notes: null,
    createdAt: at,
    updatedAt: at,
    currentNutrition: nutrition,
    plannedNutrition: nutrition,
    consumedNutrition: nutrition,
    plannedNutritionDiffersFromCurrent: false,
    consumedNutritionDiffersFromCurrent: false,
    historicalNutritionUnavailable: false,
  );
}

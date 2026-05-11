import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealDetailsData add-on metrics', () {
    test('sums extra item and larger consumed planned item net carbs', () {
      final details = MealDetailsData(
        meal: _meal(status: 'eaten-extra'),
        advisorDecision: null,
        ingredients: [
          _ingredient(
            plannedTotalGrams: 100,
            consumedTotalGrams: 150,
            carbsPer100g: 20,
            fiberPer100g: 2,
          ),
          _ingredient(
            entryType: 'extra',
            plannedAmount: 0,
            consumedAmount: 1,
            plannedTotalGrams: 0,
            consumedTotalGrams: 40,
            carbsPer100g: 25,
            fiberPer100g: 5,
          ),
        ],
        plannedSnapshot: null,
        consumedSnapshot: null,
        statusHistory: const [],
      );

      expect(details.hasAddOn, true);
      expect(details.addOnNetCarbsG, 17);
    });

    test('detects add-on status even when carbs delta is not available', () {
      final details = MealDetailsData(
        meal: _meal(status: 'eating-extra'),
        advisorDecision: null,
        ingredients: const [],
        plannedSnapshot: null,
        consumedSnapshot: null,
        statusHistory: const [],
      );

      expect(details.hasAddOn, true);
      expect(details.addOnNetCarbsG, 0);
    });
  });
}

MealRecordData _meal({required String status}) {
  final now = DateTime(2026, 5, 11, 12);
  return MealRecordData(
    id: 1,
    name: 'Obiad',
    status: status,
    plannedAt: now,
    summarizedAt: null,
    mealTemplateId: null,
    basedOnMealId: null,
    notes: null,
    createdAt: now,
    updatedAt: now,
    isSynced: false,
  );
}

MealIngredientDetailsData _ingredient({
  String entryType = 'planned',
  double plannedAmount = 1,
  double? consumedAmount = 1.5,
  required double plannedTotalGrams,
  required double consumedTotalGrams,
  required double carbsPer100g,
  required double fiberPer100g,
}) {
  final now = DateTime(2026, 5, 11, 12);
  final nutrition = IngredientNutritionData(
    carbsPer100g: carbsPer100g,
    fatPer100g: 0,
    fiberPer100g: fiberPer100g,
    proteinPer100g: 0,
    nutritionConfidence: 1,
    effectiveAt: now,
  );
  return MealIngredientDetailsData(
    mealIngredientId: 1,
    ingredientId: 1,
    ingredientName: 'Ryż',
    entryType: entryType,
    portionLabel: 'porcja',
    plannedAmount: plannedAmount,
    consumedAmount: consumedAmount,
    quantityConfidence: 1,
    consumedConfidence: 1,
    plannedTotalGrams: plannedTotalGrams,
    consumedTotalGrams: consumedTotalGrams,
    prepMethod: null,
    notes: null,
    createdAt: now,
    updatedAt: now,
    currentNutrition: nutrition,
    plannedNutrition: nutrition,
    consumedNutrition: nutrition,
    plannedNutritionDiffersFromCurrent: false,
    consumedNutritionDiffersFromCurrent: false,
    historicalNutritionUnavailable: false,
  );
}

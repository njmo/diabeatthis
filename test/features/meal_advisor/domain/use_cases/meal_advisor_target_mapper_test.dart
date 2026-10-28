import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_advisor_target_mapper.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../meal_analysis/build_before_meal_context_use_case_test.dart'
    show cutoff, macros;

MealDetailsData targetDetails({
  String status = 'planned',
  bool futureEdit = false,
}) => MealDetailsData(
  meal: MealRecordData(
    id: 1,
    name: 'Planned breakfast',
    status: status,
    plannedAt: cutoff,
    summarizedAt: null,
    mealTemplateId: null,
    basedOnMealId: null,
    notes: null,
    createdAt: cutoff.subtract(const Duration(days: 1)),
    updatedAt: futureEdit ? cutoff.add(const Duration(seconds: 1)) : cutoff,
    isSynced: false,
  ),
  advisorDecision: null,
  ingredients: [targetIngredient(), targetIngredient(extra: true)],
  plannedSnapshot: null,
  consumedSnapshot: null,
  statusHistory: [],
);
MealIngredientDetailsData targetIngredient({bool extra = false}) {
  const nutrition = IngredientNutritionData(
    carbsPer100g: 20,
    fatPer100g: 0,
    fiberPer100g: 0,
    proteinPer100g: 0,
    carbsLabelMode: CarbsLabelMode.eu,
    nutritionConfidence: 0.8,
    effectiveAt: null,
  );
  return MealIngredientDetailsData(
    mealIngredientId: extra ? 2 : 1,
    ingredientId: extra ? 2 : 1,
    ingredientName: extra ? 'Later extra' : 'Bread',
    entryType: extra ? 'extra' : 'planned',
    portionLabel: 'g',
    plannedAmount: 30,
    consumedAmount: 100,
    quantityConfidence: 0.5,
    consumedConfidence: 0.9,
    plannedTotalGrams: 30,
    consumedTotalGrams: 100,
    prepMethod: null,
    notes: null,
    createdAt: cutoff,
    updatedAt: cutoff,
    currentNutrition: nutrition,
    plannedNutrition: nutrition,
    consumedNutrition: nutrition,
    plannedNutritionDiffersFromCurrent: false,
    consumedNutritionDiffersFromCurrent: false,
    historicalNutritionUnavailable: false,
  );
}

void main() {
  test(
    'planned target uses current macros and planned portions without extras or future consumption',
    () {
      final result = const MealAdvisorTargetMapper().map(
        targetDetails(),
        macros,
        cutoff,
      );
      expect(result.macros, same(macros));
      expect(result.ingredients, [(name: 'Bread', grams: 30.0)]);
      expect(result.composition!.totalGrams, 30);
      expect(result.confidence, isNull);
    },
  );
  test(
    'later edits and already consumed meals cannot masquerade as a plan at cutoff',
    () {
      for (final details in [
        targetDetails(futureEdit: true),
        targetDetails(status: 'summarized'),
      ]) {
        expect(
          () => const MealAdvisorTargetMapper().map(details, macros, cutoff),
          throwsStateError,
        );
      }
    },
  );
}

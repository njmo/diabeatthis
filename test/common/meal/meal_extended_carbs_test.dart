import 'package:diabeatthis/common/meal/meal_extended_carbs.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealMacroSummary macros(double fat, double protein) => MealMacroSummary(
    carbsGrams: 20,
    fatGrams: fat,
    proteinGrams: protein,
    fiberGrams: 0,
    totalGrams: 100,
  );

  test('half a portion can fall below the existing WBT threshold', () {
    expect(mealExtendedCarbsFromMacros(macros(10, 5)), 11);
    expect(mealExtendedCarbsFromMacros(macros(5, 2.5)), 0);
  });

  test('half a larger portion is calculated from its actual macros', () {
    expect(mealExtendedCarbsFromMacros(macros(20, 10)), 22);
    expect(mealExtendedCarbsFromMacros(macros(10, 5)), 11);
  });

  test('exactly one WBT and absent macros produce no suggestion', () {
    expect(mealExtendedCarbsFromMacros(macros(0, 25)), 0);
    expect(mealExtendedCarbsFromMacros(null), 0);
  });
}

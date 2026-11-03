import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/mappers/ingredient_nutrition_mapper.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OLD-state history resolves before, between and after edits', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Rice',
            carbsPer100g: 30,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: .9,
            createdAt: const Value(1000),
            updatedAt: const Value(4000),
          ),
        );
    for (final state in [
      (at: 2000, carbs: 20.0, confidence: .4),
      (at: 4000, carbs: 25.0, confidence: .7),
    ]) {
      await db
          .into(db.ingredientStatusHistory)
          .insert(
            IngredientStatusHistoryCompanion.insert(
              ingredientId: ingredient.id,
              carbsPer100g: state.carbs,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: state.confidence,
              createdAt: Value(state.at),
            ),
          );
    }
    final history = await db.ingredientDao.getIngredientStatusHistory(
      ingredient.id,
    );
    for (final scenario in [
      (at: 1500, carbs: 20.0, confidence: .4),
      (at: 3000, carbs: 25.0, confidence: .7),
      (at: 4000, carbs: 30.0, confidence: .9),
    ]) {
      final result = const IngredientNutritionMapper().at(
        ingredient: ingredient,
        history: history,
        reference: DateTime.fromMillisecondsSinceEpoch(scenario.at),
      );
      expect(result.nutrition.carbsPer100g, scenario.carbs);
      expect(result.nutrition.nutritionConfidence, scenario.confidence);
      expect(result.historicalUnavailable, false);
    }
  });
}

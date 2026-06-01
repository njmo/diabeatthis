import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('meal copy search ranks meals by matching ingredients', () async {
    final rice = await _insertIngredient(db, 'Ryż');
    final chicken = await _insertIngredient(db, 'Kurczak');
    final yogurt = await _insertIngredient(db, 'Jogurt');

    final matchingMeal = await _insertMeal(db, 'Obiad ryż z kurczakiem');
    await _insertMealIngredient(db, matchingMeal.id, rice.id);
    await _insertMealIngredient(db, matchingMeal.id, chicken.id);

    final partialMeal = await _insertMeal(db, 'Obiad z ryżem');
    await _insertMealIngredient(db, partialMeal.id, rice.id);

    final otherMeal = await _insertMeal(db, 'Obiad jogurt');
    await _insertMealIngredient(db, otherMeal.id, yogurt.id);

    final result = await db.mealDao.searchMealsByNameAndIngredientIds(
      queryString: 'Obiad',
      ingredientIds: [rice.id, chicken.id],
    );

    expect(result.map((meal) => meal.id), [matchingMeal.id, partialMeal.id]);
  });

  test('meal copy search ranks templates by matching ingredients', () async {
    final rice = await _insertIngredient(db, 'Ryż');
    final chicken = await _insertIngredient(db, 'Kurczak');

    final matchingTemplate = await _insertTemplate(
      db,
      'Szablon ryż z kurczakiem',
    );
    await _insertMealTemplateIngredient(db, matchingTemplate.id, rice.id);
    await _insertMealTemplateIngredient(db, matchingTemplate.id, chicken.id);

    final partialTemplate = await _insertTemplate(db, 'Szablon ryż');
    await _insertMealTemplateIngredient(db, partialTemplate.id, rice.id);

    final result = await db.mealTemplateDao
        .searchMealTemplatesByNameAndIngredientIds(
          queryString: 'Szablon',
          ingredientIds: [rice.id, chicken.id],
        );

    expect(result.map((template) => template.id), [
      matchingTemplate.id,
      partialTemplate.id,
    ]);
  });
}

Future<IngredientData> _insertIngredient(DatabaseImpl db, String name) {
  return db
      .into(db.ingredient)
      .insertReturning(
        IngredientCompanion.insert(
          name: name,
          carbsPer100g: 10,
          fatPer100g: 1,
          fiberPer100g: 1,
          proteinPer100g: 2,
          nutritionConfidence: 0.8,
        ),
      );
}

Future<MealData> _insertMeal(DatabaseImpl db, String name) {
  return db
      .into(db.meal)
      .insertReturning(
        MealCompanion.insert(
          name: name,
          plannedAt: DateTime(2026).millisecondsSinceEpoch,
        ),
      );
}

Future<void> _insertMealIngredient(
  DatabaseImpl db,
  int mealId,
  int ingredientId,
) {
  return db
      .into(db.mealIngredients)
      .insert(
        MealIngredientsCompanion.insert(
          mealId: mealId,
          ingredientId: ingredientId,
          amount: const Value(1),
          quantityConfidence: 0.8,
        ),
      );
}

Future<MealTemplateData> _insertTemplate(DatabaseImpl db, String name) {
  return db
      .into(db.mealTemplate)
      .insertReturning(MealTemplateCompanion.insert(name: name));
}

Future<void> _insertMealTemplateIngredient(
  DatabaseImpl db,
  int mealTemplateId,
  int ingredientId,
) {
  return db
      .into(db.mealTemplateIngredients)
      .insert(
        MealTemplateIngredientsCompanion.insert(
          mealTemplateId: mealTemplateId,
          ingredientId: ingredientId,
          quantityConfidence: 0.8,
        ),
      );
}

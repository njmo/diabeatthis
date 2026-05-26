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

  test('macro update stores previous values in history', () async {
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Ryż',
            carbsPer100g: 28,
            fatPer100g: 0.3,
            fiberPer100g: 0.4,
            proteinPer100g: 2.7,
            nutritionConfidence: 0.5,
          ),
        );

    await db.ingredientDao.updateIngredientDetails(
      ingredientId: ingredient.id,
      name: 'Ryż gotowany',
      carbsPer100g: 30,
      fatPer100g: 0.4,
      fiberPer100g: 0.5,
      proteinPer100g: 2.9,
      nutritionConfidence: 0.75,
      isReference: false,
      brand: null,
    );

    final historyAfterMacroChange = await db.ingredientDao
        .getIngredientStatusHistory(ingredient.id);

    expect(historyAfterMacroChange, hasLength(1));
    expect(historyAfterMacroChange.single.carbsPer100g, 28);
    expect(historyAfterMacroChange.single.fatPer100g, 0.3);
    expect(historyAfterMacroChange.single.fiberPer100g, 0.4);
    expect(historyAfterMacroChange.single.proteinPer100g, 2.7);
    expect(historyAfterMacroChange.single.nutritionConfidence, 0.5);

    await db.ingredientDao.updateIngredientDetails(
      ingredientId: ingredient.id,
      name: 'Ryż basmati gotowany',
      carbsPer100g: 30,
      fatPer100g: 0.4,
      fiberPer100g: 0.5,
      proteinPer100g: 2.9,
      nutritionConfidence: 0.75,
      isReference: false,
      brand: null,
    );

    final historyAfterNameChange = await db.ingredientDao
        .getIngredientStatusHistory(ingredient.id);
    final updatedIngredient = await db.ingredientDao.getIngredientById(
      ingredient.id,
    );

    expect(historyAfterNameChange, hasLength(1));
    expect(updatedIngredient.name, 'Ryż basmati gotowany');
  });

  test('ingredient query matches brand', () async {
    await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Jogurt naturalny',
            carbsPer100g: 5,
            fatPer100g: 2,
            fiberPer100g: 0,
            proteinPer100g: 4,
            nutritionConfidence: 0.8,
            brand: const Value('Fantasia'),
          ),
        );
    await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Jogurt naturalny',
            carbsPer100g: 4,
            fatPer100g: 3,
            fiberPer100g: 0,
            proteinPer100g: 5,
            nutritionConfidence: 0.8,
            brand: const Value('Inna marka'),
          ),
        );

    final result = await db.ingredientDao.searchIngredientsByQuery(
      queryString: 'fantasia',
      limit: 6,
    );

    expect(result, hasLength(1));
    expect(result.single.brand, 'Fantasia');
  });
}

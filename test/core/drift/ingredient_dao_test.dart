import 'package:diabeatthis/core/drift/database_impl.dart';
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

  test('macro update creates history but name-only update does not', () async {
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
    expect(historyAfterMacroChange.single.carbsPer100g, 30);
    expect(historyAfterMacroChange.single.fatPer100g, 0.4);
    expect(historyAfterMacroChange.single.fiberPer100g, 0.5);
    expect(historyAfterMacroChange.single.proteinPer100g, 2.9);
    expect(historyAfterMacroChange.single.nutritionConfidence, 0.75);

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
}

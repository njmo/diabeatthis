import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reference in [false, true]) {
    test(
      'confidence-only changes are ordered deterministically at identical times, reference=$reference',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Ingredient',
                carbsPer100g: 20,
                fatPer100g: 4,
                fiberPer100g: 0,
                proteinPer100g: 5,
                nutritionConfidence: 0.25,
                isReference: Value(reference ? 1 : 0),
              ),
            );
        for (final confidence in [0.5, 0.75]) {
          await db.ingredientDao.updateIngredientDetails(
            ingredientId: id,
            name: 'Ingredient',
            carbsPer100g: 20,
            fatPer100g: 4,
            fiberPer100g: 0,
            proteinPer100g: 5,
            nutritionConfidence: confidence,
            isReference: reference,
            brand: null,
            barcode: null,
          );
        }
        await db
            .update(db.ingredientStatusHistory)
            .write(
              const IngredientStatusHistoryCompanion(createdAt: Value(1234)),
            );
        final history = await db.ingredientDao.getIngredientStatusHistory(id);
        expect(history.map((entry) => entry.nutritionConfidence), [0.5, 0.25]);
        expect(history.map((entry) => entry.carbsPer100g), [20, 20]);
      },
    );
  }
}

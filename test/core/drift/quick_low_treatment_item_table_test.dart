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

  test('stores quick low treatment item for ingredient and portion', () async {
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Dextro',
            carbsPer100g: 90,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
          ),
        );
    final portion = await db
        .into(db.portion)
        .insertReturning(
          PortionCompanion.insert(name: 'cukierek', unitHint: 'szt.'),
        );

    final item = await db
        .into(db.quickLowTreatmentItem)
        .insertReturning(
          QuickLowTreatmentItemCompanion.insert(
            name: 'Dextro',
            ingredientId: ingredient.id,
            portionId: Value(portion.id),
            amount: 1,
            sortOrder: const Value(1),
          ),
        );

    expect(item.name, 'Dextro');
    expect(item.ingredientId, ingredient.id);
    expect(item.portionId, portion.id);
    expect(item.amount, 1);
    expect(item.isSynced, isFalse);
  });
}

import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/update_ingredient_details_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('keeps saved label mode when updating existing ingredient', () async {
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Ryż',
            carbsPer100g: 28,
            fatPer100g: 0.3,
            fiberPer100g: 0.4,
            proteinPer100g: 2.7,
            nutritionConfidence: 0.8,
            carbsLabelMode: const Value('non_eu'),
          ),
        );

    final useCase = container.read(updateIngredientDetailsUseCaseProvider);
    await useCase.call(
      IngredientDraft.existing(
        id: ingredient.id,
        name: ingredient.name,
        carbsPer100g: ingredient.carbsPer100g,
        fatPer100g: ingredient.fatPer100g,
        fiberPer100g: ingredient.fiberPer100g,
        proteinPer100g: ingredient.proteinPer100g,
        nutritionConfidence: ingredient.nutritionConfidence,
        isReference: false,
        carbsLabelMode: CarbsLabelMode.eu,
      ),
    );

    final updated = await db.ingredientDao.getIngredientById(ingredient.id);

    expect(updated.carbsLabelMode, 'non_eu');
  });

  test('clears barcode when updating reference ingredient', () async {
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Referencyjny obiad',
            carbsPer100g: 28,
            fatPer100g: 8,
            fiberPer100g: 0,
            proteinPer100g: 14,
            nutritionConfidence: 0.8,
            isReference: const Value(1),
            barcode: const Value('5900385503415'),
          ),
        );

    final useCase = container.read(updateIngredientDetailsUseCaseProvider);
    await useCase.call(
      IngredientDraft.existing(
        id: ingredient.id,
        name: ingredient.name,
        carbsPer100g: ingredient.carbsPer100g,
        fatPer100g: ingredient.fatPer100g,
        fiberPer100g: ingredient.fiberPer100g,
        proteinPer100g: ingredient.proteinPer100g,
        nutritionConfidence: ingredient.nutritionConfidence,
        isReference: true,
        barcode: ingredient.barcode,
      ),
    );

    final updated = await db.ingredientDao.getIngredientById(ingredient.id);

    expect(updated.barcode, null);
  });
}

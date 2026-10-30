import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/update_ingredient_details_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'editing an existing ingredient saves and replaces its icon without nutrition history',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final saved = await db
          .into(db.ingredient)
          .insertReturning(
            IngredientCompanion.insert(
              name: 'Apple',
              carbsPer100g: 12,
              fatPer100g: 0,
              fiberPer100g: 2,
              proteinPer100g: 0,
              nutritionConfidence: 1,
            ),
          );
      final draft = IngredientDraft.existing(
        id: saved.id,
        name: saved.name,
        carbsPer100g: 12,
        fatPer100g: 0,
        fiberPer100g: 2,
        proteinPer100g: 0,
        nutritionConfidence: 1,
        isReference: false,
      );
      final useCase = container.read(updateIngredientDetailsUseCaseProvider);
      for (final icon in ['apple', 'banana']) {
        await useCase.call(
          draft.copyWith(iconAssetPath: 'assets/icons/food/$icon.png'),
        );
        expect(
          (await db.ingredientDao.getIngredientById(saved.id)).iconAssetPath,
          'assets/icons/food/$icon.png',
        );
      }
      await useCase.call(draft);
      expect(
        (await db.ingredientDao.getIngredientById(saved.id)).iconAssetPath,
        'assets/icons/food/banana.png',
      );
      expect(await db.select(db.ingredientStatusHistory).get(), isEmpty);
    },
  );
}

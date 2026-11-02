import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_name_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_name_formatter.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  test(
    'dominant ingredients compare resolved grams, portions and reference portions',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(subscription.close);
      final base = mealFlowIngredient(container);
      final draft = container.read(mealDraftProvider.notifier);
      draft.setMealIngredients([
        base.copyWith(
          ingredient: base.ingredient.copyWith(name: 'Honey'),
          amount: 2,
          ingredientPortion: base.ingredientPortion.copyWith(
            portion: const PortionSelection.draft(
              name: 'Green spoon',
              unitHint: 'g',
            ),
            amount: 8,
          ),
        ),
        base.copyWith(
          ingredient: base.ingredient.copyWith(name: 'Oats'),
          amount: 50,
        ),
        base.copyWith(
          ingredient: base.ingredient.copyWith(
            name: 'Estimated yogurt',
            isReference: true,
          ),
          amount: 2,
        ),
      ]);
      expect(await container.read(mealNameIngredientsProvider.future), [
        'Estimated yogurt',
        'Oats',
      ]);
      draft.setMealIngredients([
        base.copyWith(ingredient: base.ingredient.copyWith(name: 'Apple')),
      ]);
      expect(await container.read(mealNameIngredientsProvider.future), [
        'Apple',
      ]);
    },
  );

  test(
    'category prefixes generated names while manual names survive updates',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(subscription.close);
      final draft = container.read(mealDraftProvider.notifier);
      final automatic = formatAutomaticMealName(lang, [
        'Tortilla',
        'Chicken',
      ], MealCategory.lunch);
      expect(automatic, contains('Tortilla, Chicken'));
      expect(automatic, startsWith('${MealCategory.lunch.label(lang)}: '));
      draft.applyGeneratedName(automatic);
      expect(container.read(mealDraftProvider).name, automatic);
      draft.setName('My lunch');
      draft.setCategory(MealCategory.dinner);
      draft.applyGeneratedName('Dinner: Something else');
      expect(container.read(mealDraftProvider).name, 'My lunch');
    },
  );

  test(
    'category persists and filters before the result limit; legacy rows survive migration',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Lunch',
              plannedAt: 1,
              category: const Value('lunch'),
            ),
          );
      await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Snack',
              plannedAt: 2,
              category: const Value('snack'),
            ),
          );
      expect(
        (await db.mealDao.watchRecentMeals(limit: 1, category: 'lunch').first)
            .single
            .name,
        'Lunch',
      );
      expect(
        (await db.mealDao
            .watchMealsByName(queryString: 'Lunch', limit: 1, category: 'snack')
            .first),
        isEmpty,
      );
      await db.customStatement('ALTER TABLE meal DROP COLUMN category');
      await db.migration.onUpgrade(Migrator(db), 40, 41);
      final rows = await db.select(db.meal).get();
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.category == null), isTrue);
    },
  );
}

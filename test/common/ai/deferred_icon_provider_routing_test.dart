import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_assets.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/persistence/insert_ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/paused_ingredient_write.dart';
import 'helpers/pending_icon_test_client.dart';
import 'helpers/recording_ai_test_client.dart';

const ingredientDraft = IngredientDraft.draft(
  name: 'Burger',
  carbsPer100g: 20,
  fatPer100g: 10,
  fiberPer100g: 0,
  proteinPer100g: 10,
  nutritionConfidence: 0.75,
  isReference: true,
);

MealDraft mealDraft() => MealDraft(
  name: 'Provider switch meal',
  plannedAt: DateTime(2026, 11, 1, 12),
  status: 'planned',
  mealIngredients: [
    MealIngredientsDraft(
      ingredient: ingredientDraft,
      ingredientPortion: const IngredientPortionDraft(
        portion: PortionSelection.empty(),
        amount: 0,
      ),
      amount: 1,
      quantityConfidence: 0.75,
      entryType: 'planned',
      consumedAmount: null,
      consumedConfidence: null,
    ),
  ],
);

void main() {
  for (final saveMeal in [false, true]) {
    final feature = saveMeal ? 'meal' : 'ingredient';
    for (final failNewService in [false, true]) {
      test(
        '$feature save ${failNewService ? 'survives an unavailable new icon service' : 'uses the selected icon provider after an awaited write'}',
        () async {
          final gate = PausedIngredientWrite();
          final db = DatabaseImpl(NativeDatabase.memory().interceptWith(gate));
          final originalClient = RecordingAiTestClient()
            ..response = '{"icon":"pizza"}';
          final selectedClient = RecordingAiTestClient()
            ..response = '{"icon":"hamburger"}';
          var switched = false;
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              databaseProvider.overrideWithValue(db),
              ingredientIconServiceProvider.overrideWith((ref) {
                if (switched && failNewService) {
                  throw StateError('Selected provider is unavailable');
                }
                return IngredientIconService(
                  client: switched ? selectedClient : originalClient,
                );
              }),
            ],
          );
          addTearDown(() async {
            if (!gate.resume.isCompleted) gate.resume.complete();
            container.dispose();
            await db.close();
          });
          final saving = saveMeal
              ? container.read(addMealUseCaseProvider).call(mealDraft())
              : container.read(
                  insertIngredientProvider(ingredientDraft).future,
                );
          await gate.reached.future.timeout(const Duration(seconds: 5));
          switched = true;
          container.invalidate(ingredientIconServiceProvider);
          gate.resume.complete();
          await saving;

          expect(originalClient.requests, isEmpty);
          if (failNewService) {
            expect(selectedClient.requests, isEmpty);
            final ingredients = await db.select(db.ingredient).get();
            expect(ingredients.single.iconAssetPath, isNull);
          } else {
            final ingredients = await db
                .select(db.ingredient)
                .watch()
                .firstWhere(
                  (rows) =>
                      rows.length == 1 && rows.single.iconAssetPath != null,
                )
                .timeout(const Duration(seconds: 5));
            expect(selectedClient.requests, hasLength(1));
            expect(
              ingredients.single.iconAssetPath,
              'assets/icons/food/hamburger.png',
            );
          }
          if (saveMeal) expect(await db.select(db.meal).get(), hasLength(1));
        },
      );
    }
  }

  test(
    'completed meal save skips deferred AI after its ref is disposed',
    () async {
      final gate = PausedIngredientWrite();
      final db = DatabaseImpl(NativeDatabase.memory().interceptWith(gate));
      final client = RecordingAiTestClient();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ingredientIconServiceProvider.overrideWithValue(
            IngredientIconService(client: client),
          ),
        ],
      );
      addTearDown(() async {
        if (!gate.resume.isCompleted) gate.resume.complete();
        await db.close();
      });
      final saving = container.read(addMealUseCaseProvider).call(mealDraft());
      await gate.reached.future.timeout(const Duration(seconds: 5));
      container.dispose();
      gate.resume.complete();
      await saving;
      expect(client.requests, isEmpty);
      expect(await db.select(db.meal).get(), hasLength(1));
    },
  );

  test(
    'prefetch persists a generic result without a second old-provider request',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final originalClient = PendingIconTestClient();
      final selectedClient = RecordingAiTestClient();
      var switched = false;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ingredientIconServiceProvider.overrideWith(
            (ref) => IngredientIconService(
              client: switched ? selectedClient : originalClient,
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final saved = await insertIngredientDraft(db, ingredientDraft);
      final refProvider = Provider((ref) => ref);
      prefetchIngredientIcon(container.read(refProvider), saved.toDraft());
      expect(originalClient.requests, hasLength(1));
      switched = true;
      container.invalidate(ingredientIconServiceProvider);
      originalClient.response.complete(
        const LocalLlmResponse(text: '{"icon":"generic"}'),
      );
      final ingredients = await db
          .select(db.ingredient)
          .watch()
          .firstWhere((rows) => rows.single.iconAssetPath != null)
          .timeout(const Duration(seconds: 5));
      expect(ingredients.single.iconAssetPath, FoodIconAssets.generic);
      expect(originalClient.requests, hasLength(1));
      expect(selectedClient.requests, isEmpty);
    },
  );
}

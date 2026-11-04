import 'dart:convert';

import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_settings.dart';
import 'package:diabeatthis/features/meal_photo/data/prepared_meal_photo_saver.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'photo_writer_transaction_test.dart';

final roundtripPhotoMacrosProvider = FutureProvider.family<Macronutrients, int>(
  (ref, id) async {
    final ingredients = await ref.read(
      getMealIngredientsDraftForMealProvider(id).future,
    );
    return calculateMealIngredientsMacronutrients(ref, ingredients);
  },
);

void main() {
  for (final scenario in [
    (
      mode: MealPhotoMode.reference,
      us: false,
      expectedCarbs: 30,
      expectedFiber: 3,
    ),
    (
      mode: MealPhotoMode.reference,
      us: true,
      expectedCarbs: 35,
      expectedFiber: 5,
    ),
    (
      mode: MealPhotoMode.itemized,
      us: false,
      expectedCarbs: 45,
      expectedFiber: 6,
    ),
  ]) {
    test(
      '275g references retain exact rounded nutrition through actual save and macro provider ${scenario.mode} US=${scenario.us}',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            ingredientIconClientProvider.overrideWithValue(
              PhotoWriterIconClient(),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final payload = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
        final total = {
          'carbs': scenario.us ? 35 : 30,
          'fiber': scenario.us ? 5 : 3,
          'fat': 2,
          'protein': 4,
          'carbs_label_mode': scenario.us ? 'non_eu' : 'eu',
        };
        (payload['reference'] as Map<String, dynamic>)['reference_nutrition'] =
            total;
        if (scenario.mode == MealPhotoMode.itemized) {
          final first = fixtures.component('first', kind: 'proposed_reference')
            ..['reference_nutrition'] = total;
          final second = fixtures.component(
            'second',
            kind: 'proposed_reference',
          )..['reference_nutrition'] = {...total, 'carbs': 15};
          payload['itemized'] = [first, second];
        }
        final proposal = const MealPhotoProposalParser().parse(
          jsonEncode(payload),
        );
        final items = proposal
            .itemsFor(scenario.mode)
            .map(
              (source) => MealPhotoReviewItem.fromProposal(source)
                  .acceptReference()
                  .adjust(
                    grams: 275,
                    quantityConfidence: .7,
                    nutritionConfidence: .6,
                    reviewed: true,
                  ),
            )
            .toList();
        final review = AcceptedMealPhotoReview(
          name: 'Photo plate',
          mode: scenario.mode,
          items: items,
          proposalResponse: proposal.rawResponse,
          sourceProposal: proposal,
        );
        final saver = PreparedMealPhotoSaver(
          ingredients: DriftMealPhotoDraftIngredientResolver(
            db: db,
            local: DriftMealPhotoLocalIngredientReader(db),
            catalogStore: DriftSelectedCatalogIngredientStore(db),
          ),
          writer: container.read(photoTestWriterProvider),
          settings: () => MealPhotoDraftSettings(
            category: MealCategory.lunch,
            plannedAt: DateTime(2026, 11, 3),
          ),
          runAtomic: (action) => db.transaction(action),
        );
        final id = await saver.save(review);
        final macros = await container.read(
          roundtripPhotoMacrosProvider(id).future,
        );
        expect(macros.carbsTotal, scenario.expectedCarbs);
        expect(macros.fiberTotal, scenario.expectedFiber);
        expect(macros.netCarbsTotal, scenario.us ? 30 : scenario.expectedCarbs);
        final saved = await db.select(db.ingredient).get();
        expect(
          saved.every((ingredient) => ingredient.isReference == 0),
          isTrue,
        );
        // Storage preserves the original normalized double; only integer consumers stabilize.
        expect(saved.first.carbsPer100g, (scenario.us ? 35 : 30) * (100 / 275));
      },
    );
  }
}

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_portion_suggestions_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/open_food_facts_product_client_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  for (final incomplete in [false, true]) {
    test(
      'barcode ${incomplete ? 'review' : 'recognized'} outcome retains serving evidence',
      () async {
        final database = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            openFoodFactsProductClientProvider.overrideWithValue(
              SuggestionProductClient(incomplete: incomplete),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await database.close();
        });

        final outcome = await container
            .read(ingredientBarcodeLookupControllerProvider.notifier)
            .scan('5900385503415');

        expect(
          outcome.type,
          incomplete
              ? IngredientBarcodeScanOutcomeType.needsReview
              : IngredientBarcodeScanOutcomeType.newDraft,
        );
        expect(outcome.portions, hasLength(1));
        expect(outcome.portions.single.name, 'Cup');
        expect(outcome.portions.single.grams, 150);
        expect(outcome.portions.single.source, 'open_food_facts');
        expect(outcome.draft?.nutritionConfidence, 0.25);
        expect(
          await database.select(database.ingredientPortions).get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'only named positive finite serving suggestions survive without being assigned',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        ingredientPortionSuggestionsProvider.notifier,
      );
      const valid = RecognizedPortion(
        name: 'Cup',
        unitHint: 'g',
        grams: 150,
        source: 'nutrition_label',
      );
      controller.setSuggestions([
        valid,
        const RecognizedPortion(
          name: '',
          unitHint: 'g',
          grams: 50,
          source: null,
        ),
        const RecognizedPortion(
          name: 'Unknown',
          unitHint: 'g',
          grams: null,
          source: null,
        ),
        const RecognizedPortion(
          name: 'Invalid',
          unitHint: 'g',
          grams: -1,
          source: null,
        ),
        const RecognizedPortion(
          name: 'Infinity',
          unitHint: 'g',
          grams: double.infinity,
          source: null,
        ),
      ]);
      expect(container.read(ingredientPortionSuggestionsProvider), [valid]);
      controller.clear();
      expect(container.read(ingredientPortionSuggestionsProvider), isEmpty);
    },
  );
}

class SuggestionProductClient extends OpenFoodFactsProductClient {
  final bool incomplete;
  SuggestionProductClient({required this.incomplete});

  @override
  Future<Map<String, dynamic>> fetchProduct(String barcode) async => {
    'status': 1,
    'product': {
      'product_name': 'Yogurt',
      'serving_quantity': 150,
      'serving_size': 'Cup',
      'nutriments': {
        'carbohydrates_100g': 5,
        if (!incomplete) 'fat_100g': 3,
        'proteins_100g': 4,
        'fiber_100g': 0,
      },
    },
  };
}

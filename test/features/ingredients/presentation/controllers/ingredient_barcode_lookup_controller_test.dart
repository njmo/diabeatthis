import 'package:diabeatthis/core/domain/model/ingredient.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/find_ingredient_by_barcode_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/find_matching_ingredient_for_scan_result_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/data/providers/open_food_facts_product_client_provider.dart';
import 'package:diabeatthis/features/ingredients/domain/services/ingredient_matcher.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('IngredientBarcodeLookupController', () {
    late DatabaseImpl db;
    late _FailingOpenFoodFactsProductClient openFoodFactsClient;
    late ProviderContainer container;

    setUp(() {
      db = DatabaseImpl(NativeDatabase.memory());
      openFoodFactsClient = _FailingOpenFoodFactsProductClient();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          openFoodFactsProductClientProvider.overrideWithValue(
            openFoodFactsClient,
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'returns local ingredient by barcode before Open Food Facts',
      () async {
        await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Lokalny produkt',
                carbsPer100g: 10,
                fatPer100g: 2,
                fiberPer100g: 1,
                proteinPer100g: 3,
                nutritionConfidence: 0.8,
                barcode: const Value('5900385503415'),
              ),
            );

        final outcome = await container
            .read(ingredientBarcodeLookupControllerProvider.notifier)
            .scan('5900385503415');

        expect(
          outcome.type,
          IngredientBarcodeScanOutcomeType.existingIngredient,
        );
        expect(outcome.existingIngredient?.name, 'Lokalny produkt');
        expect(openFoodFactsClient.wasCalled, false);
      },
    );

    test('returns draft from Open Food Facts when ingredient is new', () async {
      openFoodFactsClient.response = {
        'status': 1,
        'product': {
          'product_name': 'Nowy produkt',
          'brands': 'Test brand',
          'nutriments': {
            'carbohydrates_100g': 11,
            'fat_100g': 2,
            'proteins_100g': 3,
            'fiber_100g': 1,
          },
        },
      };

      final outcome = await container
          .read(ingredientBarcodeLookupControllerProvider.notifier)
          .scan('5900385503415');

      expect(outcome.type, IngredientBarcodeScanOutcomeType.newDraft);
      expect(outcome.draft?.name, 'Nowy produkt');
      expect(outcome.draft?.barcode, '5900385503415');
      expect(openFoodFactsClient.wasCalled, true);
    });

    test('returns Open Food Facts draft when local matching fails', () async {
      final matchingContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          openFoodFactsProductClientProvider.overrideWithValue(
            openFoodFactsClient,
          ),
          findMatchingIngredientForScanResultUseCaseProvider.overrideWithValue(
            _ThrowingFindMatchingIngredientUseCase(db),
          ),
        ],
      );
      addTearDown(matchingContainer.dispose);
      openFoodFactsClient.response = {
        'status': 1,
        'product': {
          'product_name': 'Bavaria 0,0% Ginger Lime',
          'brands': 'Bavaria',
          'nutriments': {
            'carbohydrates_100g': 7.90909090909091,
            'fat_100g': 0,
            'proteins_100g': 0.0909090909090909,
            'fiber_100g': 0,
          },
        },
      };

      final outcome = await matchingContainer
          .read(ingredientBarcodeLookupControllerProvider.notifier)
          .scan('8714800048378');

      expect(outcome.type, IngredientBarcodeScanOutcomeType.newDraft);
      expect(outcome.draft?.name, 'Bavaria 0,0% Ginger Lime');
      expect(outcome.draft?.barcode, '8714800048378');
    });

    test(
      'returns existing ingredient without barcode by normalized name',
      () async {
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
              ),
            );
        openFoodFactsClient.response = {
          'status': 1,
          'product': {
            'product_name': 'Jogurt-naturalny',
            'nutriments': {
              'carbohydrates_100g': 5,
              'fat_100g': 2,
              'proteins_100g': 4,
              'fiber_100g': 0,
            },
          },
        };

        final outcome = await container
            .read(ingredientBarcodeLookupControllerProvider.notifier)
            .scan('5900385503415');

        expect(
          outcome.type,
          IngredientBarcodeScanOutcomeType.existingIngredient,
        );
        expect(outcome.existingIngredient?.name, 'Jogurt naturalny');
        expect(outcome.existingIngredient?.barcode, '5900385503415');
        final savedIngredient = await db.ingredientDao.getIngredientById(
          outcome.existingIngredient!.id,
        );
        expect(savedIngredient.barcode, '5900385503415');
      },
    );

    test(
      'returns existing ingredient without barcode when local brand is empty',
      () async {
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
              ),
            );
        openFoodFactsClient.response = {
          'status': 1,
          'product': {
            'product_name': 'Jogurt naturalny',
            'brands': 'Bakoma',
            'nutriments': {
              'carbohydrates_100g': 5,
              'fat_100g': 2,
              'proteins_100g': 4,
              'fiber_100g': 0,
            },
          },
        };

        final outcome = await container
            .read(ingredientBarcodeLookupControllerProvider.notifier)
            .scan('5900385503415');

        expect(
          outcome.type,
          IngredientBarcodeScanOutcomeType.existingIngredient,
        );
        expect(outcome.existingIngredient?.name, 'Jogurt naturalny');
      },
    );

    test(
      'returns existing Bavaria ingredient without barcode by Open Food Facts name',
      () async {
        await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Bavaria 0,0% Ginger Lime',
                brand: const Value('Bavaria'),
                carbsPer100g: 7.90909090909091,
                fatPer100g: 0,
                fiberPer100g: 0,
                proteinPer100g: 0.0909090909090909,
                nutritionConfidence: 0.8,
              ),
            );
        openFoodFactsClient.response = {
          'status': 1,
          'product': {
            'product_name': 'Bavaria 0,0% Ginger Lime',
            'brands': 'Bavaria',
            'brands_tags': ['Bavaria'],
            'nutriments': {
              'carbohydrates_100g': 7.90909090909091,
              'fat_100g': 0,
              'proteins_100g': 0.0909090909090909,
              'fiber_100g': 0,
            },
            'serving_quantity': 330,
            'serving_size': '330 mL',
          },
        };

        final outcome = await container
            .read(ingredientBarcodeLookupControllerProvider.notifier)
            .scan('8714800048378');

        expect(
          outcome.type,
          IngredientBarcodeScanOutcomeType.existingIngredient,
        );
        expect(outcome.existingIngredient?.name, 'Bavaria 0,0% Ginger Lime');
        expect(outcome.existingIngredient?.barcode, '8714800048378');
        final savedIngredient = await db.ingredientDao.getIngredientById(
          outcome.existingIngredient!.id,
        );
        expect(savedIngredient.barcode, '8714800048378');
      },
    );

    test('returns review draft when Open Food Facts has only name', () async {
      openFoodFactsClient.response = {
        'status': 1,
        'product': {'product_name': 'Produkt bez makro'},
      };

      final outcome = await container
          .read(ingredientBarcodeLookupControllerProvider.notifier)
          .scan('5900385503415');

      expect(outcome.type, IngredientBarcodeScanOutcomeType.needsReview);
      expect(outcome.draft?.name, 'Produkt bez makro');
      expect(outcome.draft?.barcode, '5900385503415');
    });
  });
}

class _FailingOpenFoodFactsProductClient extends OpenFoodFactsProductClient {
  var wasCalled = false;
  Map<String, dynamic>? response;

  @override
  Future<Map<String, dynamic>> fetchProduct(String barcode) async {
    wasCalled = true;
    final response = this.response;
    if (response != null) {
      return response;
    }
    throw StateError('Open Food Facts should not be called.');
  }
}

class _ThrowingFindMatchingIngredientUseCase
    extends FindMatchingIngredientForScanResultUseCase {
  _ThrowingFindMatchingIngredientUseCase(DatabaseImpl db)
    : super(
        db: db,
        findIngredientByBarcode: FindIngredientByBarcodeUseCase(db: db),
        matcher: const IngredientMatcher(),
      );

  @override
  Future<domain.Ingredient?> call(IngredientScanResult result) async {
    throw StateError('Local matching failed.');
  }
}

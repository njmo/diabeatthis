import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_result.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/open_food_facts_product_client_provider.dart';
import 'package:diabeatthis/features/ingredients/domain/use_cases/scan_ingredient_from_barcode_use_case.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_photo_scan_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/persistence/resolve_portion_selection.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  late DatabaseImpl database;
  late ImportRegressionProductClient productClient;
  late ProviderContainer container;

  setUp(() {
    database = DatabaseImpl(NativeDatabase.memory());
    productClient = ImportRegressionProductClient();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        openFoodFactsProductClientProvider.overrideWithValue(productClient),
        cameraPermissionServiceProvider.overrideWithValue(
          CameraPermissionService(
            getStatus: () async => PermissionStatus.granted,
          ),
        ),
        ingredientPhotoScanClientProvider.overrideWithValue(
          const DebugIngredientPhotoScanClient(delay: Duration.zero),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'local barcode preserves identity, macros, confidence and assigned weights',
    () async {
      final ingredientId = await database
          .into(database.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Saved apple',
              barcode: const Value('5900385503415'),
              carbsPer100g: 12,
              fatPer100g: 0.2,
              fiberPer100g: 2,
              proteinPer100g: 0.3,
              nutritionConfidence: 0.75,
            ),
          );
      final portion = await resolvePortionSelection(
        database,
        const PortionSelection.draft(name: 'Small apple', unitHint: 'g'),
      );
      await database.insertIngredientPortion(ingredientId, portion!.id, 125);

      final outcome = await container
          .read(ingredientBarcodeLookupControllerProvider.notifier)
          .scan('5900385503415');

      expect(outcome.type, IngredientBarcodeScanOutcomeType.existingIngredient);
      expect(outcome.existingIngredient?.id, ingredientId);
      expect(outcome.existingIngredient?.carbsPer100g, 12);
      expect(outcome.existingIngredient?.nutritionConfidence, 0.75);
      expect(productClient.calls, 0);
      expect(
        await database.portionDao.getGramsPerPortion(ingredientId, portion.id),
        125,
      );
    },
  );

  test(
    'external barcode is a reviewable draft without silently saving a product',
    () async {
      final outcome = await container
          .read(ingredientBarcodeLookupControllerProvider.notifier)
          .scan('5900385503415');

      expect(outcome.type, IngredientBarcodeScanOutcomeType.newDraft);
      expect(outcome.draft?.name, 'Imported yogurt');
      expect(outcome.draft?.brand, 'Dairy');
      expect(outcome.draft?.barcode, '5900385503415');
      expect(outcome.draft?.carbsPer100g, 5);
      expect(outcome.draft?.fatPer100g, 3);
      expect(outcome.draft?.proteinPer100g, 4);
      expect(outcome.draft?.fiberPer100g, 0);
      expect(outcome.draft?.nutritionConfidence, 0.25);
      expect(await database.select(database.ingredient).get(), isEmpty);
      expect(await database.select(database.ingredientPortions).get(), isEmpty);
    },
  );

  test(
    'external serving suggestion retains source and grams before user assignment',
    () async {
      final result = await container
          .read(scanIngredientFromBarcodeUseCaseProvider)
          .call('5900385503415');

      expect(result.portions, hasLength(1));
      expect(result.portions.single.name, '1 cup (150 g)');
      expect(result.portions.single.grams, 150);
      expect(result.portions.single.source, 'open_food_facts');
      expect(await database.select(database.ingredientPortions).get(), isEmpty);
    },
  );

  test(
    'front and label photos produce editable nutrition and retain serving evidence',
    () async {
      container.listen(ingredientPhotoScanCaptureControllerProvider, (_, _) {});
      container.listen(ingredientPhotoScanControllerProvider, (_, _) {});
      final capture = container.read(
        ingredientPhotoScanCaptureControllerProvider.notifier,
      );
      await capture.capture(
        IngredientPhotoScanPhoto.front,
        capturePhoto: () async =>
            CameraPhotoCaptureResult.captured('/tmp/front.jpg'),
      );
      await capture.capture(
        IngredientPhotoScanPhoto.nutritionLabel,
        capturePhoto: () async =>
            CameraPhotoCaptureResult.captured('/tmp/label.jpg'),
      );

      final controller = container.read(
        ingredientPhotoScanControllerProvider.notifier,
      );
      final draft = await controller.scanIngredient();
      final result = container
          .read(ingredientPhotoScanControllerProvider)
          .value;

      expect(draft, isNotNull);
      expect(draft?.carbsPer100g, 62.3);
      expect(draft?.proteinPer100g, 6.4);
      expect(draft?.fiberPer100g, 3.2);
      expect(draft?.nutritionConfidence, 0.25);
      expect(result?.portions.single.name, '2 ciastka');
      expect(result?.portions.single.grams, 25);
      expect(result?.portions.single.source, 'nutrition_label');
      expect(controller.draftFromCurrentResult(), draft);
      expect(
        container
            .read(ingredientPhotoScanCaptureControllerProvider)
            .hasRequiredPhotos,
        isTrue,
      );
    },
  );

  test(
    'a shared portion name has independent reusable weights for each ingredient',
    () async {
      final firstIngredientId = await database
          .into(database.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Apple',
              carbsPer100g: 12,
              fatPer100g: 0.2,
              fiberPer100g: 2,
              proteinPer100g: 0.3,
              nutritionConfidence: 0.75,
            ),
          );
      final secondIngredientId = await database
          .into(database.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Pear',
              carbsPer100g: 13,
              fatPer100g: 0.1,
              fiberPer100g: 3,
              proteinPer100g: 0.4,
              nutritionConfidence: 0.5,
            ),
          );
      const selection = PortionSelection.draft(
        name: 'A whole fruit',
        unitHint: 'g',
      );
      final firstSelection = (await resolvePortionSelection(
        database,
        selection,
      ))!;
      final secondSelection = (await resolvePortionSelection(
        database,
        selection,
      ))!;
      expect(secondSelection.id, firstSelection.id);

      await database.insertIngredientPortion(
        firstIngredientId,
        firstSelection.id,
        150,
      );
      final unassigned = await database.portionDao
          .getUnassignedPortionsForIngredientByQuery(
            secondIngredientId,
            'whole',
          );
      expect(
        unassigned.map((portion) => portion.id),
        contains(firstSelection.id),
      );
      await database.insertIngredientPortion(
        secondIngredientId,
        secondSelection.id,
        200,
      );
      await database.insertIngredientPortion(
        firstIngredientId,
        firstSelection.id,
        999,
      );

      expect(
        await database.portionDao.getGramsPerPortion(
          firstIngredientId,
          firstSelection.id,
        ),
        150,
      );
      expect(
        await database.portionDao.getGramsPerPortion(
          secondIngredientId,
          secondSelection.id,
        ),
        200,
      );
      expect(
        await database.portionDao.getUnassignedPortionsForIngredientByQuery(
          secondIngredientId,
          'whole',
        ),
        isEmpty,
      );
      expect(
        await database.portionDao.getPortionsForIngredientByQuery(
          secondIngredientId,
          'whole',
        ),
        hasLength(1),
      );
    },
  );
}

class ImportRegressionProductClient extends OpenFoodFactsProductClient {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetchProduct(String barcode) async {
    calls += 1;
    return {
      'status': 1,
      'product': {
        'product_name': 'Imported yogurt',
        'brands': 'Dairy',
        'serving_quantity': 150,
        'serving_size': '1 cup (150 g)',
        'nutriments': {
          'carbohydrates_100g': 5,
          'fat_100g': 3,
          'proteins_100g': 4,
          'fiber_100g': 0,
        },
      },
    };
  }
}

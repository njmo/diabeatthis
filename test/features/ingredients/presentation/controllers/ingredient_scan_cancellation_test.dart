import 'dart:async';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_result.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/clients/ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/open_food_facts_product_client_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_photo_scan_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test(
    'closing a flow while an external code is loading ignores its late result',
    () async {
      final database = DatabaseImpl(NativeDatabase.memory());
      addTearDown(database.close);
      final client = DeferredBarcodeProductClient();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          openFoodFactsProductClientProvider.overrideWithValue(client),
        ],
      );
      container.listen(ingredientBarcodeLookupControllerProvider, (_, _) {});
      final pending = container
          .read(ingredientBarcodeLookupControllerProvider.notifier)
          .scan('5900385503415');
      await client.started.future;
      container.dispose();
      client.response.complete({
        'status': 1,
        'product': {
          'product_name': 'Late yogurt',
          'nutriments': {
            'carbohydrates_100g': 5,
            'fat_100g': 3,
            'proteins_100g': 4,
            'fiber_100g': 0,
          },
        },
      });

      expect((await pending).type, IngredientBarcodeScanOutcomeType.failed);
      expect(await database.select(database.ingredient).get(), isEmpty);
    },
  );

  test(
    'closing a flow while label photos are loading ignores its late result',
    () async {
      final client = DeferredLabelScanClient();
      final container = ProviderContainer(
        overrides: [
          cameraPermissionServiceProvider.overrideWithValue(
            CameraPermissionService(
              getStatus: () async => PermissionStatus.granted,
            ),
          ),
          ingredientPhotoScanClientProvider.overrideWithValue(client),
        ],
      );
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
      final pending = container
          .read(ingredientPhotoScanControllerProvider.notifier)
          .scanIngredient();
      await client.started.future;
      container.dispose();
      client.response.complete(debugIngredientPhotoScanResponse);

      expect(await pending, isNull);
    },
  );
}

class DeferredBarcodeProductClient extends OpenFoodFactsProductClient {
  final started = Completer<void>();
  final response = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> fetchProduct(String barcode) {
    started.complete();
    return response.future;
  }
}

class DeferredLabelScanClient implements IngredientPhotoScanClient {
  final started = Completer<void>();
  final response = Completer<String>();

  @override
  Future<String> scan(IngredientPhotoScanInput input) {
    started.complete();
    return response.future;
  }
}

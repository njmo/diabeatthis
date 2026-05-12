import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/core/media/providers/camera_photo_capture_service_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('IngredientPhotoScanController', () {
    test('keeps scan errors in state without throwing from the flow', () async {
      var photoNumber = 0;
      final container = ProviderContainer(
        overrides: [
          cameraPermissionServiceProvider.overrideWithValue(
            CameraPermissionService(
              getStatus: () async => PermissionStatus.granted,
            ),
          ),
          cameraPhotoCaptureServiceProvider.overrideWithValue(
            CameraPhotoCaptureService(
              pickFromCamera: () async {
                photoNumber += 1;
                return XFile('/tmp/photo-$photoNumber.jpg');
              },
            ),
          ),
          ingredientPhotoScanClientProvider.overrideWithValue(
            const _UnavailableIngredientPhotoScanClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(ingredientPhotoScanCaptureControllerProvider.notifier)
          .capture(IngredientPhotoScanPhoto.front);
      await container
          .read(ingredientPhotoScanCaptureControllerProvider.notifier)
          .capture(IngredientPhotoScanPhoto.nutritionLabel);

      final result = await container
          .read(ingredientPhotoScanControllerProvider.notifier)
          .scanIngredient();

      expect(result, isNull);
      final state = container.read(ingredientPhotoScanControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<LocalLlmUnavailableException>());
    });
  });
}

class _UnavailableIngredientPhotoScanClient
    implements IngredientPhotoScanClient {
  const _UnavailableIngredientPhotoScanClient();

  @override
  Future<String> scan(IngredientPhotoScanInput input) async {
    throw const LocalLlmUnavailableException();
  }
}

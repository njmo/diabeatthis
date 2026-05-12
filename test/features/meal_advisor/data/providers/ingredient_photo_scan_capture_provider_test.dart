import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/core/media/providers/camera_photo_capture_service_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('IngredientPhotoScanCaptureController', () {
    test('stores captured photo path', () async {
      final container = ProviderContainer(
        overrides: [
          cameraPermissionServiceProvider.overrideWithValue(
            CameraPermissionService(
              getStatus: () async => PermissionStatus.granted,
            ),
          ),
          cameraPhotoCaptureServiceProvider.overrideWithValue(
            CameraPhotoCaptureService(
              pickFromCamera: () async => XFile('/tmp/nutrition.jpg'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(ingredientPhotoScanCaptureControllerProvider.notifier)
          .capture(IngredientPhotoScanPhoto.nutritionLabel);

      expect(result.state, IngredientPhotoCaptureState.captured);
      final input = container.read(
        ingredientPhotoScanCaptureControllerProvider,
      );
      expect(input.frontPhotoPath, isNull);
      expect(input.nutritionLabelPhotoPath, '/tmp/nutrition.jpg');
    });

    test('does not open camera when permission is denied', () async {
      var pickerCalled = false;
      final container = ProviderContainer(
        overrides: [
          cameraPermissionServiceProvider.overrideWithValue(
            CameraPermissionService(
              getStatus: () async => PermissionStatus.permanentlyDenied,
            ),
          ),
          cameraPhotoCaptureServiceProvider.overrideWithValue(
            CameraPhotoCaptureService(
              pickFromCamera: () async {
                pickerCalled = true;
                return XFile('/tmp/front.jpg');
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(ingredientPhotoScanCaptureControllerProvider.notifier)
          .capture(IngredientPhotoScanPhoto.front);

      expect(
        result.state,
        IngredientPhotoCaptureState.permissionPermanentlyDenied,
      );
      expect(result.canOpenSettings, isTrue);
      expect(pickerCalled, isFalse);
      final input = container.read(
        ingredientPhotoScanCaptureControllerProvider,
      );
      expect(input.frontPhotoPath, isNull);
      expect(input.nutritionLabelPhotoPath, isNull);
    });

    test('keeps previous state when camera is cancelled', () async {
      final container = ProviderContainer(
        overrides: [
          cameraPermissionServiceProvider.overrideWithValue(
            CameraPermissionService(
              getStatus: () async => PermissionStatus.granted,
            ),
          ),
          cameraPhotoCaptureServiceProvider.overrideWithValue(
            CameraPhotoCaptureService(pickFromCamera: () async => null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(ingredientPhotoScanCaptureControllerProvider.notifier)
          .capture(IngredientPhotoScanPhoto.front);

      expect(result.state, IngredientPhotoCaptureState.cancelled);
      final input = container.read(
        ingredientPhotoScanCaptureControllerProvider,
      );
      expect(input.frontPhotoPath, isNull);
      expect(input.nutritionLabelPhotoPath, isNull);
    });
  });
}

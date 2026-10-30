import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/core/media/providers/camera_photo_capture_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  ProviderContainer createContainer({bool granted = true}) {
    final container = ProviderContainer(
      overrides: [
        cameraPermissionServiceProvider.overrideWithValue(
          CameraPermissionService(
            getStatus: () async => granted
                ? PermissionStatus.granted
                : PermissionStatus.permanentlyDenied,
          ),
        ),
        cameraPhotoCaptureServiceProvider.overrideWithValue(
          CameraPhotoCaptureService(
            pickFromCamera: () async =>
                throw StateError('Must not open the system camera'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'accepts an automatically cropped photo without opening the system camera',
    () async {
      final container = createContainer();
      final result = await container
          .read(ingredientPhotoScanCaptureControllerProvider.notifier)
          .capture(
            IngredientPhotoScanPhoto.nutritionLabel,
            capturePhoto: () async =>
                const CameraPhotoCaptureResult.captured('/tmp/frame.jpg'),
          );
      expect(result.state, IngredientPhotoCaptureState.captured);
      expect(
        container
            .read(ingredientPhotoScanCaptureControllerProvider)
            .nutritionLabelPhotoPath,
        '/tmp/frame.jpg',
      );
    },
  );

  test('does not open the framed camera without permission', () async {
    final container = createContainer(granted: false);
    final result = await container
        .read(ingredientPhotoScanCaptureControllerProvider.notifier)
        .capture(
          IngredientPhotoScanPhoto.front,
          capturePhoto: () async =>
              throw StateError('Must not open camera without permission'),
        );
    expect(
      result.state,
      IngredientPhotoCaptureState.permissionPermanentlyDenied,
    );
  });

  test('cancelling the live camera keeps the accepted photo', () async {
    final container = createContainer();
    final controller = container.read(
      ingredientPhotoScanCaptureControllerProvider.notifier,
    );
    await controller.capture(
      IngredientPhotoScanPhoto.front,
      capturePhoto: () async =>
          const CameraPhotoCaptureResult.captured('/tmp/accepted.jpg'),
    );
    final result = await controller.capture(
      IngredientPhotoScanPhoto.front,
      capturePhoto: () async => const CameraPhotoCaptureResult.cancelled(),
    );
    expect(result.state, IngredientPhotoCaptureState.cancelled);
    expect(
      container
          .read(ingredientPhotoScanCaptureControllerProvider)
          .frontPhotoPath,
      '/tmp/accepted.jpg',
    );
  });
}

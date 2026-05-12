import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/core/media/providers/camera_photo_capture_service_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('AddMealIngredientStageNotifier', () {
    test(
      'goes back to ingredient search after successful photo scan draft',
      () async {
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
              const DebugIngredientPhotoScanClient(delay: Duration.zero),
            ),
          ],
        );
        addTearDown(container.dispose);
        final stageSubscription = container.listen(
          addMealIngredientStageProvider,
          (_, _) {},
        );
        addTearDown(stageSubscription.close);
        final scanSubscription = container.listen(
          ingredientPhotoScanControllerProvider,
          (_, _) {},
        );
        addTearDown(scanSubscription.close);

        final notifier = container.read(
          addMealIngredientStageProvider.notifier,
        );

        notifier.startIngredientPhotoScan();
        expect(
          container.read(addMealIngredientStageProvider),
          AddMealIngredientStage.ingredientPhotoScan,
        );

        await container
            .read(ingredientPhotoScanCaptureControllerProvider.notifier)
            .capture(IngredientPhotoScanPhoto.front);
        await container
            .read(ingredientPhotoScanCaptureControllerProvider.notifier)
            .capture(IngredientPhotoScanPhoto.nutritionLabel);
        await notifier.nextStage();

        expect(
          container.read(addMealIngredientStageProvider),
          AddMealIngredientStage.ingredientForm,
        );

        notifier.back();

        expect(
          container.read(addMealIngredientStageProvider),
          AddMealIngredientStage.ingredientSearch,
        );
      },
    );

    test('goes back to ingredient search directly from photo scan', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(addMealIngredientStageProvider.notifier);

      notifier.startIngredientPhotoScan();
      notifier.back();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientSearch,
      );
    });
  });
}

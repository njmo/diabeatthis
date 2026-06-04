import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/core/media/providers/camera_photo_capture_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_filter.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
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

    test('uses dismiss stage as the root back target', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(addMealIngredientStageProvider.notifier);

      notifier.back();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.dismiss,
      );
    });

    test('keeps full back path after moving past ingredient form', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(addMealIngredientStageProvider.notifier);

      notifier.startManualIngredient();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientForm,
      );

      await notifier.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionAddNewSearch,
      );

      await notifier.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionSpecifyAmount,
      );

      notifier.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionAddNewSearch,
      );

      notifier.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientForm,
      );

      notifier.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientSearch,
      );

      notifier.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.dismiss,
      );
    });

    test('keeps portion weight in meal ingredient draft', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(addMealIngredientStageProvider.notifier);

      notifier.startManualIngredient();
      await notifier.nextStage();
      await notifier.nextStage();
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(75);

      await notifier.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.amountForm,
      );

      notifier.back();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionSpecifyAmount,
      );
      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.amount,
        75,
      );
    });

    test('opens existing portions when modifying existing ingredient', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredient(_existingIngredient(id: 12));
      final notifier = container.read(addMealIngredientStageProvider.notifier);

      notifier.modifyIngredientStage(false);

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.definedPortionsSearch,
      );
      expect(
        container.read(portionFilterProvider),
        const PortionFilter.byQueryForIngredient(ingredientId: 12),
      );

      notifier.back();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.dismiss,
      );
    });
  });
}

IngredientDraft _existingIngredient({required int id}) {
  return IngredientDraft.existing(
    id: id,
    name: 'Ryż',
    carbsPer100g: 25,
    fatPer100g: 1,
    fiberPer100g: 1,
    proteinPer100g: 3,
    nutritionConfidence: 0.9,
    isReference: false,
  );
}

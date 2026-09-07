import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/core/media/providers/camera_photo_capture_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_scan_result_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/confidence_slider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_filter.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('AddMealIngredientStageNotifier', () {
    for (final isReference in [false, true]) {
      test(
        'preserves edited ingredient data (reference: $isReference)',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final draftSubscription = container.listen(
            mealIngredientsDraftProvider,
            (_, _) {},
          );
          addTearDown(draftSubscription.close);
          final confidenceSubscription = container.listen(
            mealIngredientConfidenceDraftProvider,
            (_, _) {},
          );
          addTearDown(confidenceSubscription.close);
          final stageSubscription = container.listen(
            addMealIngredientStageProvider,
            (_, _) {},
          );
          addTearDown(stageSubscription.close);
          final amountSubscription = container.listen(
            mealIngredientAmountDraftProvider,
            (_, _) {},
          );
          addTearDown(amountSubscription.close);
          final draftNotifier = container.read(
            mealIngredientsDraftProvider.notifier,
          );
          final original = container
              .read(mealIngredientsDraftProvider)
              .copyWith(
                mealIngredientId: 42,
                ingredient: _existingIngredient(
                  id: 12,
                ).copyWith(isReference: isReference),
                ingredientPortion: IngredientPortionDraft(
                  portion: isReference
                      ? const PortionSelection.empty()
                      : const PortionSelection.existing(
                          id: 7,
                          name: 'łyżka',
                          unitHint: 'g',
                        ),
                  amount: isReference ? 100 : 20,
                ),
                amount: 2,
                quantityConfidence: 0.8,
                entryType: 'extra',
                consumedAmount: 1.5,
                consumedConfidence: 0.95,
              );
          draftNotifier.overrideMealIngredient(original);
          final notifier = container.read(
            addMealIngredientStageProvider.notifier,
          );
          notifier.modifyIngredientStage(isReference);

          expect(container.read(mealIngredientsDraftProvider), original);
          expect(
            container.read(mealIngredientConfidenceDraftProvider),
            ConfidenceLevel.high,
          );
          if (!isReference) {
            // Keep the existing portion selection and advance to its amount form.
            container
                .read(portionDraftProvider.notifier)
                .overrideDraft(original.ingredientPortion.portion);
            await notifier.nextStage();
          }
          await notifier.nextStage();
          expect(container.read(mealIngredientsDraftProvider), original);

          notifier.back();
          container
              .read(mealIngredientConfidenceDraftProvider.notifier)
              .setConfidence(ConfidenceLevel.low);
          await notifier.nextStage();
          expect(
            container.read(mealIngredientsDraftProvider),
            original.copyWith(quantityConfidence: 0.25),
          );
        },
      );
    }

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

    test('opens existing portions for existing barcode ingredient', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(addMealIngredientStageProvider.notifier);

      notifier.continueWithExistingBarcodeIngredient(
        _existingIngredient(id: 12).toDomain(),
      );

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.definedPortionsSearch,
      );
      expect(
        container.read(portionFilterProvider),
        const PortionFilter.byQueryForIngredient(ingredientId: 12),
      );
      expect(
        container
            .read(mealIngredientsDraftProvider)
            .ingredient
            .getIngredientIdOrNull(),
        12,
      );
    });

    test('keeps barcode result with product name as usable draft data', () {
      const result = IngredientScanResult(
        status: IngredientScanStatus.needsReview,
        name: 'keczup łagodny kotlin 0 dodatku cukru',
        brand: null,
        barcode: '5900385503415',
        nutritionPer100g: NutritionPer100g(
          carbs: null,
          fat: null,
          protein: null,
          fiber: null,
        ),
        portions: [],
        retakeRequest: null,
      );

      expect(result.hasUsableBarcodeDraftData, isTrue);
      expect(result.toIngredientDraft().name, result.name);
      expect(result.toIngredientDraft().barcode, result.barcode);
    });

    test('does not keep barcode result without product name', () {
      const result = IngredientScanResult(
        status: IngredientScanStatus.needsReview,
        name: null,
        brand: 'Test brand',
        barcode: '5900385503415',
        nutritionPer100g: NutritionPer100g(
          carbs: 12,
          fat: null,
          protein: null,
          fiber: null,
        ),
        portions: [],
        retakeRequest: null,
      );

      expect(result.hasUsableBarcodeDraftData, isFalse);
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

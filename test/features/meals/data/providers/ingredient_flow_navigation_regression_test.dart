import 'dart:async';

import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/core/domain/model/portion.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_result.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/clients/ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/data/persistence/insert_ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_filter.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  for (final reference in [false, true]) {
    test(
      'returning to creation menu keeps entered data and icon (reference: $reference)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(addMealIngredientStageProvider, (_, _) {});
        final flow = container.read(addMealIngredientStageProvider.notifier);
        flow.startIngredientCreation();
        if (reference) {
          flow.startReferenceIngredient();
        } else {
          flow.startManualIngredient();
        }
        final draft = container.read(ingredientDraftProvider.notifier);
        draft.setName('Custom dinner');
        draft.setCarbsPer100g('42');
        draft.setNutritionConfidence(ConfidenceLevel.high);
        draft.overrideDraft(
          container
              .read(ingredientDraftProvider)
              .copyWith(iconAssetPath: 'assets/icons/food/prepared_meal.png'),
        );
        final before = container.read(ingredientDraftProvider);
        flow.back();
        if (reference) {
          flow.startReferenceIngredient();
        } else {
          flow.startManualIngredient();
        }
        expect(container.read(ingredientDraftProvider), before);
      },
    );
  }

  for (final assigned in [false, true]) {
    test(
      'creating a duplicate global name reuses its identity and stored weight (assigned: $assigned)',
      () async {
        final db = DatabaseImpl.withStandardPortions(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        container.listen(addMealIngredientStageProvider, (_, _) {});
        final flow = container.read(addMealIngredientStageProvider.notifier);
        final input = container
            .read(ingredientDraftProvider)
            .copyWith(
              name: 'Apple',
              carbsPer100g: 12,
              iconAssetPath: 'assets/icons/food/prepared_meal.png',
            );
        final ingredient = await insertIngredientDraft(db, input);
        final portion = (await db.select(db.portion).get()).single;
        if (assigned) {
          await db.insertIngredientPortion(ingredient.id, portion.id, 150);
        }
        flow.continueWithExistingBarcodeIngredient(ingredient);
        flow.toOppositeStage();
        flow.toOppositeStage();
        container
            .read(portionDraftProvider.notifier)
            .overrideDraft(
              const PortionSelection.draft(name: 'sztuka', unitHint: 'g'),
            );
        await flow.confirmNewPortion();
        expect(
          container.read(addMealIngredientStageProvider),
          assigned
              ? AddMealIngredientStage.amountForm
              : AddMealIngredientStage.portionSpecifyAmount,
        );
        final draft = container.read(mealIngredientsDraftProvider);
        expect(
          draft.ingredientPortion.portion,
          PortionSelection.existing(
            id: portion.id,
            name: 'piece',
            unitHint: 'g',
          ),
        );
        expect(draft.ingredientPortion.amount, assigned ? 150 : 0);
        expect(
          await db.portionDao.getGramsPerPortion(ingredient.id, portion.id),
          assigned ? 150 : isNull,
        );
        expect(await db.select(db.portion).get(), hasLength(1));
        if (assigned) {
          flow.back();
          expect(
            container.read(addMealIngredientStageProvider),
            AddMealIngredientStage.definedPortionsSearch,
          );
          expect(
            container.read(portionFilterProvider),
            PortionFilter.byQueryForIngredient(ingredientId: ingredient.id),
          );
        } else {
          flow.back();
          expect(
            container.read(addMealIngredientStageProvider),
            AddMealIngredientStage.portionAddNewSearch,
          );
          expect(
            container.read(portionFilterProvider),
            PortionFilter.allUnassignedForIngredient(
              ingredientId: ingredient.id,
            ),
          );
        }
      },
    );
  }

  test(
    'a photo scan finishing after Back cannot advance the ingredient sheet',
    () async {
      final client = PendingPhotoScanClient();
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
      addTearDown(container.dispose);
      container.listen(addMealIngredientStageProvider, (_, _) {});
      final flow = container.read(addMealIngredientStageProvider.notifier);
      flow.startIngredientCreation();
      flow.startIngredientPhotoScan();
      final capture = container.read(
        ingredientPhotoScanCaptureControllerProvider.notifier,
      );
      for (final photo in IngredientPhotoScanPhoto.values) {
        await capture.capture(
          photo,
          capturePhoto: () async => CameraPhotoCaptureResult.captured(
            '/tmp/navigation-${photo.name}.jpg',
          ),
        );
      }
      final pending = flow.nextStage();
      await client.started.future;
      flow.back();
      client.response.complete(debugIngredientPhotoScanResponse);
      await pending;
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientCreationMethod,
      );
      expect(container.read(ingredientDraftProvider).name, isEmpty);
      expect(
        container
            .read(ingredientPhotoScanCaptureControllerProvider)
            .hasRequiredPhotos,
        isTrue,
      );
    },
  );

  test(
    'a suggested portion lookup finishing after Back cannot select a portion or advance',
    () async {
      final portions = Completer<List<domain.Portion>>();
      final container = ProviderContainer(
        overrides: [portionsProvider.overrideWith((ref) => portions.future)],
      );
      addTearDown(container.dispose);
      container.listen(addMealIngredientStageProvider, (_, _) {});
      final flow = container.read(addMealIngredientStageProvider.notifier);
      flow.startManualIngredient();
      container.read(ingredientDraftProvider.notifier).setName('Apple');
      await flow.nextStage();
      const suggestion = RecognizedPortion(
        name: 'piece',
        unitHint: 'g',
        grams: 150,
        source: 'label',
      );
      final pending = flow.selectSuggestedPortion(suggestion);
      flow.back();
      portions.complete([
        const domain.Portion(id: 1, name: 'piece', unitHint: 'g'),
      ]);
      await pending;
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientForm,
      );
      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.amount,
        0,
      );
      expect(
        container.read(portionDraftProvider),
        const PortionSelection.draft(name: '', unitHint: ''),
      );
    },
  );

  test(
    'Back from global portions restores the filter for assigned ingredient portions',
    () async {
      final db = DatabaseImpl.withStandardPortions(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      container.listen(addMealIngredientStageProvider, (_, _) {});
      final flow = container.read(addMealIngredientStageProvider.notifier);
      final ingredient = await insertIngredientDraft(
        db,
        container
            .read(ingredientDraftProvider)
            .copyWith(
              name: 'Apple',
              carbsPer100g: 12,
              iconAssetPath: 'assets/icons/food/prepared_meal.png',
            ),
      );
      flow.continueWithExistingBarcodeIngredient(ingredient);
      flow.toOppositeStage();
      expect(
        container.read(portionFilterProvider),
        PortionFilter.allUnassignedForIngredient(ingredientId: ingredient.id),
      );
      flow.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.definedPortionsSearch,
      );
      expect(
        container.read(portionFilterProvider),
        PortionFilter.byQueryForIngredient(ingredientId: ingredient.id),
      );
    },
  );
}

class PendingPhotoScanClient implements IngredientPhotoScanClient {
  final started = Completer<void>();
  final response = Completer<String>();

  @override
  Future<String> scan(IngredientPhotoScanInput input) {
    started.complete();
    return response.future;
  }
}

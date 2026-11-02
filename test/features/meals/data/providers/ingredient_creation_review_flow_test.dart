import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/media/camera_permission_service.dart';
import 'package:diabeatthis/core/media/camera_photo_capture_result.dart';
import 'package:diabeatthis/core/media/providers/camera_permission_service_provider.dart';
import 'package:diabeatthis/features/ingredients/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/data/persistence/insert_ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_portion_suggestions_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_search_query_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late AddMealIngredientStageNotifier flow;

  setUp(() {
    db = DatabaseImpl.withStandardPortions(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
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
    container.listen(addMealIngredientStageProvider, (_, _) {});
    flow = container.read(addMealIngredientStageProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'creation menu keeps the searched name for manual and reference creation',
    () {
      container
          .read(ingredientSearchQueryProvider.notifier)
          .setQuery('  Homemade pasta  ');
      flow.startIngredientCreation();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientCreationMethod,
      );
      flow.startManualIngredient();
      expect(container.read(ingredientDraftProvider).name, 'Homemade pasta');
      flow.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientCreationMethod,
      );
      flow.startReferenceIngredient();
      final draft = container.read(ingredientDraftProvider);
      expect(draft.name, 'Homemade pasta');
      expect(draft.isReference, isTrue);
      expect(draft.nutritionConfidence, 0.25);
      expect(
        container.read(mealIngredientConfidenceDraftProvider),
        ConfidenceLevel.low,
      );
    },
  );

  test(
    'summary retains amount and confidence when returning to the amount step',
    () async {
      flow.startManualIngredient();
      container
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(reviewIngredient());
      await flow.nextStage();
      flow.setOverride();
      container.read(mealIngredientAmountDraftProvider.notifier).setValue(275);
      container
          .read(mealIngredientConfidenceDraftProvider.notifier)
          .setConfidence(ConfidenceLevel.certain);
      await flow.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.summary,
      );
      final before = flow.completeAmountForm();
      expect(before.amount, 275);
      expect(before.quantityConfidence, 0.95);
      flow.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.amountForm,
      );
      expect(container.read(mealIngredientAmountDraftProvider), 275);
      container.read(mealIngredientAmountDraftProvider.notifier).setValue(325);
      await flow.nextStage();
      expect(flow.completeAmountForm(), before.copyWith(amount: 325));
    },
  );

  test('ordinary ingredient data cannot be edited while adding', () {
    expect(flow.editReferenceIngredient, throwsStateError);
    expect(
      container.read(addMealIngredientStageProvider),
      AddMealIngredientStage.ingredientSearch,
    );
  });

  for (final changeReference in [false, true]) {
    test(
      'reference edit saves a separate variant only when changed (changed: $changeReference)',
      () async {
        final original = await insertIngredientDraft(
          db,
          reviewIngredient(isReference: true),
        );
        container
            .read(ingredientDraftProvider.notifier)
            .overrideDraft(original.toDraft());
        await flow.nextStage();
        container
            .read(mealIngredientAmountDraftProvider.notifier)
            .setValue(1.5);
        flow.editReferenceIngredient();
        expect(
          container.read(addMealIngredientStageProvider),
          AddMealIngredientStage.referenceIngredientForm,
        );
        if (changeReference) {
          final draft = container.read(ingredientDraftProvider.notifier);
          draft.setCarbsPer100g('60');
          draft.setNutritionConfidence(ConfidenceLevel.certain);
        }
        await flow.nextStage();
        expect(
          container.read(addMealIngredientStageProvider),
          AddMealIngredientStage.amountForm,
        );
        expect(container.read(mealIngredientAmountDraftProvider), 1.5);
        await flow.nextStage();
        final result = flow.completeAmountForm();
        expect(
          result.ingredient.getIngredientIdOrNull(),
          changeReference ? isNull : original.id,
        );
        final meal = await container
            .read(addMealUseCaseProvider)
            .call(
              MealDraft(
                name: 'Reference review',
                mealIngredients: [result],
                plannedAt: DateTime.utc(2026, 11, 2, 12),
                status: 'planned',
              ),
            );
        final entry = (await db.mealIngredientsDao.getMealIngredientsForMeal(
          meal.id,
        )).single;
        final saved = await db.ingredientDao.getIngredientById(
          entry.ingredientId,
        );
        final unchanged = await db.ingredientDao.getIngredientById(original.id);
        expect(saved.carbsPer100g, changeReference ? 60 : 40);
        expect(saved.nutritionConfidence, changeReference ? 0.95 : 0.75);
        expect(unchanged.carbsPer100g, 40);
        expect(unchanged.nutritionConfidence, 0.75);
        expect(
          (await db.select(db.ingredient).get()).length,
          changeReference ? 2 : 1,
        );
      },
    );
  }

  test(
    'photo review back retains both photos and manual nutrition corrections',
    () async {
      flow.startIngredientCreation();
      flow.startIngredientPhotoScan();
      final capture = container.read(
        ingredientPhotoScanCaptureControllerProvider.notifier,
      );
      await capture.capture(
        IngredientPhotoScanPhoto.front,
        capturePhoto: () async =>
            const CameraPhotoCaptureResult.captured('/tmp/flow-front.jpg'),
      );
      await capture.capture(
        IngredientPhotoScanPhoto.nutritionLabel,
        capturePhoto: () async =>
            const CameraPhotoCaptureResult.captured('/tmp/flow-label.jpg'),
      );
      await flow.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientForm,
      );
      container.read(ingredientDraftProvider.notifier).setCarbsPer100g('24');
      flow.back();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.ingredientPhotoScan,
      );
      final photos = container.read(
        ingredientPhotoScanCaptureControllerProvider,
      );
      expect(photos.frontPhotoPath, '/tmp/flow-front.jpg');
      expect(photos.nutritionLabelPhotoPath, '/tmp/flow-label.jpg');
      await flow.nextStage();
      expect(container.read(ingredientDraftProvider).carbsPer100g, 24);
    },
  );

  test(
    'imported portion uses an existing global alias and presents its suggested weight for confirmation',
    () async {
      const suggestion = RecognizedPortion(
        name: 'sztuka',
        unitHint: 'sztuka',
        grams: 150,
        source: 'label',
      );
      flow.continueWithBarcodeIngredientDraft(
        reviewIngredient(),
        portions: [suggestion],
      );
      await flow.nextStage();
      expect(container.read(ingredientPortionSuggestionsProvider), [
        suggestion,
      ]);
      await flow.selectSuggestedPortion(suggestion);
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionSpecifyAmount,
      );
      final draft = container.read(mealIngredientsDraftProvider);
      expect(draft.ingredientPortion.amount, 150);
      draft.ingredientPortion.portion.map(
        existing: (portion) {
          expect(portion.name, 'piece');
          expect(portion.unitHint, 'g');
        },
        draft: (_) =>
            fail('A recognized standard portion must reuse the global record'),
        empty: (_) => fail('A recognized standard portion must be selected'),
      );
    },
  );

  test(
    'an unknown imported portion prefills its name, gram unit and editable weight',
    () async {
      const suggestion = RecognizedPortion(
        name: 'bottle',
        unitHint: 'bottle',
        grams: 330,
        source: 'package',
      );
      flow.continueWithBarcodeIngredientDraft(
        reviewIngredient(),
        portions: [suggestion],
      );
      await flow.nextStage();
      await flow.selectSuggestedPortion(suggestion);
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionAddNewForm,
      );
      expect(
        container.read(portionDraftProvider),
        const PortionSelection.draft(name: 'bottle', unitHint: 'g'),
      );
      await flow.nextStage();
      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.amount,
        330,
      );
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(340);
      await flow.nextStage();
      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.amount,
        340,
      );
    },
  );

  test(
    'cancelling a reference edit restores data before another search selection',
    () async {
      final original = await insertIngredientDraft(
        db,
        reviewIngredient(isReference: true),
      );
      container
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(original.toDraft());
      await flow.nextStage();
      flow.editReferenceIngredient();
      container.read(ingredientDraftProvider.notifier).setCarbsPer100g('60');
      flow.back();
      expect(container.read(ingredientDraftProvider), original.toDraft());
      expect(
        container.read(mealIngredientsDraftProvider).ingredient,
        original.toDraft(),
      );
    },
  );

  test(
    'choosing an existing ingredient clears suggestions from a previous import',
    () async {
      const suggestion = RecognizedPortion(
        name: 'bottle',
        unitHint: 'bottle',
        grams: 330,
        source: 'package',
      );
      flow.continueWithBarcodeIngredientDraft(
        reviewIngredient(),
        portions: [suggestion],
      );
      flow.back();
      final original = await insertIngredientDraft(db, reviewIngredient());
      container
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(original.toDraft());
      await flow.nextStage();
      flow.toOppositeStage();
      expect(container.read(ingredientPortionSuggestionsProvider), isEmpty);
    },
  );

  test(
    'switching creation methods cannot reuse a manual draft as a photo result',
    () async {
      flow.startIngredientCreation();
      flow.startIngredientPhotoScan();
      final capture = container.read(
        ingredientPhotoScanCaptureControllerProvider.notifier,
      );
      await capture.capture(
        IngredientPhotoScanPhoto.front,
        capturePhoto: () async =>
            const CameraPhotoCaptureResult.captured('/tmp/flow-front.jpg'),
      );
      await capture.capture(
        IngredientPhotoScanPhoto.nutritionLabel,
        capturePhoto: () async =>
            const CameraPhotoCaptureResult.captured('/tmp/flow-label.jpg'),
      );
      await flow.nextStage();
      final photoDraft = container.read(ingredientDraftProvider);
      flow.back();
      flow.back();
      flow.startManualIngredient();
      container
          .read(ingredientDraftProvider.notifier)
          .setName('Manual ingredient');
      flow.back();
      flow.startIngredientPhotoScan();
      await flow.nextStage();
      expect(container.read(ingredientDraftProvider), photoDraft);
    },
  );
}

IngredientDraft reviewIngredient({bool isReference = false}) =>
    IngredientDraft.draft(
      name: 'Pasta',
      carbsPer100g: 40,
      fatPer100g: 10,
      fiberPer100g: 0,
      proteinPer100g: 25,
      nutritionConfidence: 0.75,
      isReference: isReference,
      iconAssetPath: 'assets/icons/food/prepared_meal.png',
    );

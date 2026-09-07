import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/navigation/step_history.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_barcode_scan_feedback_controller.dart';
import '../../../ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import '../../../meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_search_controller.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/drafts/portion_filter.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../drafts/meal_draft.dart';
import 'meal_draft_provider.dart';

part 'add_ingredients_provider.g.dart';

enum AddMealIngredientStage {
  dismiss,
  ingredientSearch,
  ingredientPhotoScan,
  ingredientForm,
  portionAddNewSearch,
  portionAddNewForm,
  portionSpecifyAmount,
  definedPortionsSearch,
  amountForm,
}

@riverpod
GlobalKey<FormState> mealIngredientFormKey(Ref ref) {
  return GlobalKey<FormState>();
}

@riverpod
GlobalKey<FormState> ingredientSearchFormKey(Ref ref) {
  return GlobalKey<FormState>();
}

@riverpod
GlobalKey<FormState> ingredientFormKey(Ref ref) {
  return GlobalKey<FormState>();
}

@riverpod
class AddMealIngredientStageNotifier extends _$AddMealIngredientStageNotifier {
  final _history = StepHistory(root: AddMealIngredientStage.dismiss);
  PortionSelection? _amountPortion;

  @override
  AddMealIngredientStage build() {
    // The flow owns these drafts even when the active stage does not display them.
    ref.watch(mealIngredientsDraftProvider.notifier);
    ref.watch(mealIngredientAmountDraftProvider.notifier);
    ref.watch(mealIngredientConfidenceDraftProvider.notifier);
    _history.reset();
    _amountPortion = null;
    return AddMealIngredientStage.ingredientSearch;
  }

  void editIngredient(MealIngredientsDraft draft) {
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .overrideMealIngredient(draft);
    _history.reset();
    _amountPortion = null;
    ref
        .read(mealIngredientConfidenceDraftProvider.notifier)
        .setConfidence(ConfidenceLevelX.fromDouble01(draft.quantityConfidence));
    if (draft.ingredient.isReference) {
      final amount = draft.amount > 0 ? draft.amount : 1.0;
      ref.read(mealIngredientAmountDraftProvider.notifier).setValue(amount);
      _amountPortion = draft.ingredientPortion.portion;
      state = AddMealIngredientStage.amountForm;
      return;
    }

    final ingredientDraft = draft.ingredient;
    final ingredientId = ingredientDraft.getIngredientIdOrNull();
    final filter = ingredientId == null
        ? PortionFilter.byQuery()
        : PortionFilter.byQueryForIngredient(ingredientId: ingredientId);
    ref.watch(portionFilterProvider.notifier).setFilter(filter);
    _openAmountForm(
      backTo: ingredientId == null
          ? AddMealIngredientStage.portionAddNewSearch
          : AddMealIngredientStage.definedPortionsSearch,
    );
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.selectIngredientPortion(PortionSelection.empty());
    _openAmountForm();
  }

  void setStage(AddMealIngredientStage stage) => _moveTo(stage);

  void startManualIngredient() {
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientFormKeyProvider);
    _moveTo(AddMealIngredientStage.ingredientForm);
  }

  void startIngredientPhotoScan() {
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    ref.invalidate(ingredientBarcodeLookupControllerProvider);
    ref.invalidate(ingredientPhotoScanControllerProvider);
    ref.invalidate(ingredientPhotoSearchControllerProvider);
    _moveTo(AddMealIngredientStage.ingredientPhotoScan);
  }

  Future<void> startIngredientPhotoSearch() async {
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    ref.invalidate(ingredientBarcodeLookupControllerProvider);
    ref.invalidate(ingredientPhotoScanControllerProvider);
    ref.invalidate(ingredientPhotoSearchControllerProvider);
    await ref
        .read(ingredientPhotoSearchControllerProvider.notifier)
        .captureAndSearch();
  }

  Future<IngredientBarcodeScanOutcome> scanIngredientBarcode(
    String barcode,
  ) async {
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    ref.invalidate(ingredientPhotoScanControllerProvider);
    ref.invalidate(ingredientPhotoSearchControllerProvider);
    final outcome = await ref
        .read(ingredientBarcodeLookupControllerProvider.notifier)
        .scan(barcode);
    return outcome;
  }

  void continueWithExistingBarcodeIngredient(domain.Ingredient ingredient) {
    final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
    ingredientDraft.overrideDraft(ingredient.toDraft());
    ref.invalidate(ingredientFormKeyProvider);
    _continueWithSelectedIngredientDraft(ingredient.toDraft());
  }

  void continueWithBarcodeIngredientDraft(IngredientDraft scannedIngredient) {
    final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
    ingredientDraft.overrideDraft(scannedIngredient);
    ref.invalidate(ingredientFormKeyProvider);
    _moveTo(
      AddMealIngredientStage.ingredientForm,
      backTo: AddMealIngredientStage.ingredientSearch,
    );
  }

  void continuePhotoSearchAsFullScan() {
    ref.invalidate(ingredientPhotoScanControllerProvider);
    _moveTo(
      AddMealIngredientStage.ingredientPhotoScan,
      backTo: AddMealIngredientStage.ingredientSearch,
    );
  }

  Future<void> nextStage() async {
    switch (state) {
      case AddMealIngredientStage.dismiss:
        throw UnimplementedError();
      case AddMealIngredientStage.ingredientSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        _continueWithSelectedIngredientDraft(ingredientDraft);
        break;
      case AddMealIngredientStage.ingredientPhotoScan:
        final scannedIngredient = await ref
            .read(ingredientPhotoScanControllerProvider.notifier)
            .scanIngredient();
        if (scannedIngredient == null) {
          break;
        }
        final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
        ingredientDraft.overrideDraft(scannedIngredient);
        ref.invalidate(ingredientFormKeyProvider);
        _moveTo(
          AddMealIngredientStage.ingredientForm,
          backTo: AddMealIngredientStage.ingredientSearch,
        );
        break;
      case AddMealIngredientStage.ingredientForm:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        if (ingredientDraft.isReference) {
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          _openAmountForm();
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(PortionFilter.byQuery());

          _moveTo(AddMealIngredientStage.portionAddNewSearch);
        }
        break;
      case AddMealIngredientStage.portionAddNewSearch:
      case AddMealIngredientStage.portionAddNewForm:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.selectIngredientPortion(portionsDraft);
        _moveTo(AddMealIngredientStage.portionSpecifyAmount);
        break;
      case AddMealIngredientStage.portionSpecifyAmount:
        _openAmountForm();
        break;
      case AddMealIngredientStage.definedPortionsSearch:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.selectIngredientPortion(portionsDraft);
        _openAmountForm();
        break;
      case AddMealIngredientStage.amountForm:
        throw StateError(
          'Complete the amount form to finish adding an ingredient',
        );
    }
  }

  MealIngredientsDraft completeAmountForm() {
    if (state != AddMealIngredientStage.amountForm) {
      throw StateError('The amount form must be open before completing it');
    }
    final amount = ref.read(mealIngredientAmountDraftProvider);
    if (amount <= 0 || !amount.isFinite) {
      throw StateError(
        'Ingredient amount must be finite and greater than zero',
      );
    }
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .applyAmountForm(
          amount: amount,
          confidence: ref.read(mealIngredientConfidenceDraftProvider),
        );
    return ref.read(mealIngredientsDraftProvider);
  }

  void toOppositeStage() {
    switch (state) {
      case AddMealIngredientStage.dismiss:
        throw UnimplementedError();
      case AddMealIngredientStage.ingredientSearch:
        startManualIngredient();
        break;
      case AddMealIngredientStage.ingredientPhotoScan:
        _moveBackTo(AddMealIngredientStage.ingredientSearch);
        break;
      case AddMealIngredientStage.definedPortionsSearch:
        final ingredientDraft = ref
            .read(mealIngredientsDraftProvider)
            .ingredient;
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(
          PortionFilter.allUnassignedForIngredient(
            ingredientId: ingredientDraft.toDomain().id,
          ),
        );
        _moveTo(AddMealIngredientStage.portionAddNewSearch);
        break;
      case AddMealIngredientStage.portionAddNewForm:
        ref.invalidate(portionDraftProvider);
        _moveTo(AddMealIngredientStage.portionAddNewSearch);
        break;
      case AddMealIngredientStage.ingredientForm:
        _moveTo(AddMealIngredientStage.ingredientSearch);
        break;
      case AddMealIngredientStage.portionAddNewSearch:
        ref.invalidate(portionDraftProvider);
        _moveTo(AddMealIngredientStage.portionAddNewForm);
        break;
      case AddMealIngredientStage.amountForm:
      case AddMealIngredientStage.portionSpecifyAmount:
        throw UnimplementedError();
    }
  }

  bool validateStage() {
    return false;
  }

  void continueWithIngredientScanReview() {
    final scannedIngredient = ref
        .read(ingredientPhotoScanControllerProvider.notifier)
        .draftFromCurrentResult();
    if (scannedIngredient == null) {
      return;
    }

    final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
    ingredientDraft.overrideDraft(scannedIngredient);
    ref.invalidate(ingredientFormKeyProvider);
    _moveTo(
      AddMealIngredientStage.ingredientForm,
      backTo: AddMealIngredientStage.ingredientSearch,
    );
  }

  void back() {
    if (state == AddMealIngredientStage.ingredientPhotoScan) {
      ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
      ref.invalidate(ingredientPhotoScanControllerProvider);
      ref.invalidate(ingredientPhotoSearchControllerProvider);
    }
    state = _history.pop();
  }

  void _moveTo(AddMealIngredientStage next, {AddMealIngredientStage? backTo}) {
    _history.push(backTo ?? state);
    state = next;
  }

  void _continueWithSelectedIngredientDraft(IngredientDraft ingredientDraft) {
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredient(ingredientDraft);
    if (ingredientDraft.isReference) {
      mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
      _openAmountForm();
      return;
    }

    final portionsFilter = ref.read(portionFilterProvider.notifier);
    portionsFilter.setFilter(
      PortionFilter.byQueryForIngredient(
        ingredientId: ingredientDraft.toDomain().id,
      ),
    );
    _moveTo(AddMealIngredientStage.definedPortionsSearch);
  }

  void _moveBackTo(AddMealIngredientStage stage) {
    _history.reset();
    state = stage;
  }

  void _openAmountForm({AddMealIngredientStage? backTo}) {
    final draft = ref.read(mealIngredientsDraftProvider);
    final portion = draft.ingredientPortion.portion;
    final amountNotifier = ref.read(mealIngredientAmountDraftProvider.notifier);
    if (_amountPortion == null) {
      amountNotifier.setValue(draft.amount > 0 ? draft.amount : 1.0);
    } else if (_amountPortion != portion) {
      amountNotifier.setValue(0);
    }
    _amountPortion = portion;
    _moveTo(AddMealIngredientStage.amountForm, backTo: backTo);
  }
}

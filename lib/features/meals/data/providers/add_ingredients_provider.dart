import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meal_advisor/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../meal_advisor/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/drafts/portion_filter.dart';
import '../../../portions/data/providers/portion_provider.dart';
import 'meal_draft_provider.dart';

part 'add_ingredients_provider.g.dart';

enum AddMealIngredientStage {
  ingredientSearch,
  ingredientPhotoScan,
  ingredientForm,
  portionAddNewSearch,
  portionAddNewForm,
  portionSpecifyAmount,
  definedPortionsSearch,
  amountForm,
  summary,
}

@riverpod
GlobalKey<FormState> mealIngredientFormKey(Ref ref) {
  return GlobalKey<FormState>();
}

@riverpod
class AddMealIngredientStageNotifier extends _$AddMealIngredientStageNotifier {
  late AddMealIngredientStage prev;
  @override
  AddMealIngredientStage build() {
    prev = AddMealIngredientStage.ingredientSearch;
    return AddMealIngredientStage.ingredientSearch;
  }

  void modifyIngredientStage(bool isReference) {
    if (isReference) {
      state = AddMealIngredientStage.amountForm;
      return;
    }
    state = AddMealIngredientStage.portionAddNewSearch;
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
    state = AddMealIngredientStage.amountForm;
  }

  void setStage(AddMealIngredientStage stage) => state = stage;

  void startManualIngredient() {
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(mealIngredientFormKeyProvider);
    _moveTo(AddMealIngredientStage.ingredientForm);
  }

  void startIngredientPhotoScan() {
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    ref.invalidate(ingredientPhotoScanControllerProvider);
    _moveTo(AddMealIngredientStage.ingredientPhotoScan);
  }

  Future<void> nextStage() async {
    switch (state) {
      case AddMealIngredientStage.ingredientSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        if (ingredientDraft.isReference) {
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          _moveTo(AddMealIngredientStage.amountForm);
        } else {
          final portionsFilter = ref.read(portionFilterProvider.notifier);
          portionsFilter.setFilter(
            PortionFilter.byQueryForIngredient(
              ingredientId: ingredientDraft.map(
                draft: (draft) => 0,
                existing: (existing) => existing.id,
              ),
            ),
          );

          _moveTo(AddMealIngredientStage.definedPortionsSearch);
        }
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
        ref.invalidate(mealIngredientFormKeyProvider);
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
          _moveTo(AddMealIngredientStage.amountForm);
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
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        _moveTo(AddMealIngredientStage.portionSpecifyAmount);
        break;
      case AddMealIngredientStage.portionSpecifyAmount:
        final ingredientAmountInPortion = ref.read(
          ingredientPortionAmountDraftProvider,
        );
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortionAmount(
          ingredientAmountInPortion,
        );
        _moveTo(AddMealIngredientStage.amountForm);
        break;
      case AddMealIngredientStage.definedPortionsSearch:
        final portionsDraft = ref.read(portionDraftProvider);
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredientPortion(portionsDraft);
        _moveTo(AddMealIngredientStage.amountForm);
        break;
      case AddMealIngredientStage.amountForm:
        final amountDraft = ref.read(mealIngredientAmountDraftProvider);
        final quantityConfidence = ref.read(
          mealIngredientConfidenceDraftProvider,
        );
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setQuantityConfidence(quantityConfidence);
        mealIngredientsDraft.setAmount(amountDraft);
        _moveTo(AddMealIngredientStage.summary);
        break;
      case AddMealIngredientStage.summary:
        throw UnimplementedError();
    }
  }

  void toOppositeStage() {
    prev = state;
    switch (state) {
      case AddMealIngredientStage.ingredientSearch:
        startManualIngredient();
        break;
      case AddMealIngredientStage.ingredientPhotoScan:
        state = AddMealIngredientStage.ingredientSearch;
        break;
      case AddMealIngredientStage.definedPortionsSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        final portionsFilter = ref.read(portionFilterProvider.notifier);
        portionsFilter.setFilter(
          PortionFilter.allUnassignedForIngredient(
            ingredientId: ingredientDraft.map(
              draft: (draft) => 0,
              existing: (existing) => existing.id,
            ),
          ),
        );
        state = AddMealIngredientStage.portionAddNewSearch;
        break;
      case AddMealIngredientStage.portionAddNewForm:
        state = AddMealIngredientStage.portionAddNewSearch;
        ref.invalidate(portionDraftProvider);
        break;
      case AddMealIngredientStage.ingredientForm:
        state = AddMealIngredientStage.ingredientSearch;
        break;
      case AddMealIngredientStage.portionAddNewSearch:
        ref.invalidate(portionDraftProvider);
        state = AddMealIngredientStage.portionAddNewForm;
        break;
      case AddMealIngredientStage.amountForm:
      case AddMealIngredientStage.summary:
      case AddMealIngredientStage.portionSpecifyAmount:
        // TODO: Handle this case.
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
    ref.invalidate(mealIngredientFormKeyProvider);
    _moveTo(
      AddMealIngredientStage.ingredientForm,
      backTo: AddMealIngredientStage.ingredientSearch,
    );
  }

  void back() {
    if (state == AddMealIngredientStage.ingredientPhotoScan) {
      ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
      ref.invalidate(ingredientPhotoScanControllerProvider);
      prev = AddMealIngredientStage.ingredientSearch;
      state = AddMealIngredientStage.ingredientSearch;
      return;
    }
    state = prev;
  }

  void _moveTo(AddMealIngredientStage next, {AddMealIngredientStage? backTo}) {
    prev = backTo ?? state;
    state = next;
  }
}

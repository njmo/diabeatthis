import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/navigation/step_history.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/portions/standard_portion_names.dart';
import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/media/camera_photo_capture_result.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/icons/ingredient_icon_provider.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../ingredients/data/models/ingredient_photo_scan_input.dart';
import '../../../ingredients/data/models/ingredient_scan_result.dart';
import '../../../ingredients/data/providers/ingredient_photo_scan_capture_provider.dart';
import '../../../ingredients/data/providers/ingredient_portion_suggestions_provider.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../ingredients/data/providers/ingredient_search_query_provider.dart';
import '../../../ingredients/presentation/controllers/ingredient_barcode_lookup_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_barcode_scan_feedback_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_photo_scan_controller.dart';
import '../../../ingredients/presentation/controllers/ingredient_photo_search_controller.dart';
import '../../../ingredients/presentation/models/ingredient_barcode_scan_outcome.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/drafts/portion_filter.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/ingredient_flow_form_providers.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../domain/use_cases/ingredient_portions_use_case.dart';

enum AddMealIngredientStage {
  dismiss,
  ingredientSearch,
  ingredientCreationMethod,
  ingredientPhotoScan,
  ingredientForm,
  referenceIngredientForm,
  portionAddNewSearch,
  portionAddNewForm,
  portionSpecifyAmount,
  definedPortionsSearch,
  amountForm,
  summary,
}

class AddMealIngredientStageNotifier extends Notifier<AddMealIngredientStage> {
  final _history = StepHistory(root: AddMealIngredientStage.dismiss);
  PortionSelection? _amountPortion;
  final _inlinePortionWeights = <PortionSelection, double>{};
  double? inlinePortionWeight(PortionSelection portion) =>
      _inlinePortionWeights[portion];
  List<PortionSelection> get inlineDefinedPortions =>
      _inlinePortionWeights.keys.toList(growable: false);
  bool _usesCreationMenu = false;
  IngredientPhotoScanInput? _reviewedPhotos;
  String? _pendingBarcode;
  bool _editingReference = false;
  IngredientDraft? _originalReference;
  IngredientBarcodeScanOutcome? _barcodeOutcome;
  RecognizedPortion? _selectedSuggestion;
  IngredientDraft? _manualDraft;
  IngredientDraft? _referenceDraft;
  bool _creatingManually = false;
  int _photoScanRequest = 0;
  int _navigationRevision = 0;

  @override
  AddMealIngredientStage build() {
    // The flow owns these drafts even when the active stage does not display them.
    ref.watch(mealIngredientsDraftProvider.notifier);
    ref.watch(mealIngredientAmountDraftProvider.notifier);
    ref.watch(mealIngredientConfidenceDraftProvider.notifier);
    ref.listen(ingredientDraftProvider, (_, _) {});
    ref.listen(portionDraftProvider, (_, _) {});
    ref.listen(ingredientPhotoScanCaptureControllerProvider, (_, _) {});
    ref.listen(ingredientPhotoScanControllerProvider, (_, _) {});
    _history.reset();
    _inlinePortionWeights.clear();
    _amountPortion = null;
    _usesCreationMenu = false;
    _reviewedPhotos = null;
    _pendingBarcode = null;
    _editingReference = false;
    _originalReference = null;
    _barcodeOutcome = null;
    _selectedSuggestion = null;
    _manualDraft = null;
    _referenceDraft = null;
    _creatingManually = false;
    _photoScanRequest = 0;
    _navigationRevision = 0;
    return AddMealIngredientStage.ingredientSearch;
  }

  void editIngredient(MealIngredientsDraft draft) {
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .overrideMealIngredient(draft);
    _history.reset();
    _inlinePortionWeights.clear();
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

  void editIngredientInline(MealIngredientsDraft draft) {
    editIngredient(draft);
    _history.reset();
  }

  Future<void> integrateAssignedPortions() async {
    if (state != AddMealIngredientStage.definedPortionsSearch) return;
    final revision = _navigationRevision;
    final ingredient = ref.read(mealIngredientsDraftProvider).ingredient;
    final selection = await ref
        .read(ingredientPortionsUseCaseProvider)
        .initialSelection(ingredient);
    if (!ref.mounted || revision != _navigationRevision) return;
    back();
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .selectIngredientPortion(selection);
    _openAmountForm();
  }

  void selectInlinePortion(PortionSelection selection) {
    final draft = ref.read(mealIngredientsDraftProvider);
    if (selection == draft.ingredientPortion.portion) return;
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .selectIngredientPortion(selection);
    final weight = _inlinePortionWeights[selection];
    if (weight != null) {
      ref
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(weight);
    }
    ref.read(mealIngredientAmountDraftProvider.notifier).setValue(0);
    _amountPortion = selection;
  }

  void defineInlinePortion() {
    final id = ref
        .read(mealIngredientsDraftProvider)
        .ingredient
        .getIngredientIdOrNull();
    ref
        .read(portionFilterProvider.notifier)
        .setFilter(
          id == null
              ? const PortionFilter.byQuery()
              : PortionFilter.allUnassignedForIngredient(ingredientId: id),
        );
    _moveTo(AddMealIngredientStage.portionAddNewSearch);
  }

  void setOverride() {
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.selectIngredientPortion(PortionSelection.empty());
    _openAmountForm();
  }

  void setStage(AddMealIngredientStage stage) => _moveTo(stage);

  void startIngredientCreation() {
    _usesCreationMenu = true;
    _moveTo(AddMealIngredientStage.ingredientCreationMethod);
  }

  void startManualIngredient() {
    ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    _selectedSuggestion = null;
    _reviewedPhotos = null;
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientFormKeyProvider);
    final draft = ref.read(ingredientDraftProvider.notifier);
    final savedDraft = _manualDraft;
    if (savedDraft != null) {
      draft.overrideDraft(savedDraft);
    } else {
      draft.setName(ref.read(ingredientSearchQueryProvider).trim());
      if (_pendingBarcode != null) draft.setBarcode(_pendingBarcode!);
    }
    _creatingManually = true;
    _moveTo(AddMealIngredientStage.ingredientForm);
  }

  void startReferenceIngredient() {
    ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    _selectedSuggestion = null;
    _reviewedPhotos = null;
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientFormKeyProvider);
    final draft = ref.read(ingredientDraftProvider.notifier);
    final savedDraft = _referenceDraft;
    if (savedDraft != null) {
      draft.overrideDraft(savedDraft);
    } else {
      draft.setName(ref.read(ingredientSearchQueryProvider).trim());
      draft.setIsReference(true);
    }
    _creatingManually = false;
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .setQuantityConfidence(ConfidenceLevel.low);
    ref
        .read(mealIngredientConfidenceDraftProvider.notifier)
        .setConfidence(ConfidenceLevel.low);
    _editingReference = false;
    _moveTo(AddMealIngredientStage.referenceIngredientForm);
  }

  void editReferenceIngredient() {
    final ingredient = ref.read(mealIngredientsDraftProvider).ingredient;
    if (!ingredient.isReference) {
      throw StateError('Only reference ingredients can be edited while adding');
    }
    ref.read(ingredientDraftProvider.notifier).overrideDraft(ingredient);
    ref.invalidate(ingredientFormKeyProvider);
    _editingReference = true;
    _originalReference = ingredient;
    _moveTo(AddMealIngredientStage.referenceIngredientForm);
  }

  void startIngredientPhotoScan() {
    _creatingManually = false;
    _selectedSuggestion = null;
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    if (!_usesCreationMenu || _reviewedPhotos == null) {
      ref.invalidate(ingredientDraftProvider);
      ref.invalidate(ingredientPhotoScanControllerProvider);
      ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    }
    if (!_usesCreationMenu) {
      ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    }
    ref.invalidate(ingredientBarcodeLookupControllerProvider);
    ref.invalidate(ingredientPhotoSearchControllerProvider);
    _moveTo(AddMealIngredientStage.ingredientPhotoScan);
  }

  Future<void> startIngredientPhotoSearch({
    required Future<CameraPhotoCaptureResult> Function() capturePhoto,
  }) async {
    _selectedSuggestion = null;
    _reviewedPhotos = null;
    _pendingBarcode = null;
    ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    ref.read(ingredientSearchQueryProvider.notifier).setQuery('');
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    ref.invalidate(ingredientBarcodeLookupControllerProvider);
    ref.invalidate(ingredientPhotoScanControllerProvider);
    ref.invalidate(ingredientPhotoSearchControllerProvider);
    await ref
        .read(ingredientPhotoSearchControllerProvider.notifier)
        .captureAndSearch(capturePhoto: capturePhoto);
  }

  Future<IngredientBarcodeScanOutcome> scanIngredientBarcode(
    String barcode,
  ) async {
    _pendingBarcode = barcode.trim();
    _manualDraft = null;
    _creatingManually = false;
    _selectedSuggestion = null;
    _reviewedPhotos = null;
    ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    ref.invalidate(ingredientBarcodeScanFeedbackProvider);
    ref.invalidate(ingredientDraftProvider);
    ref.invalidate(ingredientPhotoScanCaptureControllerProvider);
    ref.invalidate(ingredientPhotoScanControllerProvider);
    ref.invalidate(ingredientPhotoSearchControllerProvider);
    final outcome = await ref
        .read(ingredientBarcodeLookupControllerProvider.notifier)
        .scan(barcode);
    _barcodeOutcome = outcome;
    return outcome;
  }

  void continueWithExistingBarcodeIngredient(domain.Ingredient ingredient) {
    ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
    ingredientDraft.overrideDraft(ingredient.toDraft());
    ref.invalidate(ingredientFormKeyProvider);
    _continueWithSelectedIngredientDraft(ingredient.toDraft());
  }

  void continueWithBarcodeIngredientDraft(
    IngredientDraft scannedIngredient, {
    List<RecognizedPortion>? portions,
  }) {
    _creatingManually = false;
    _selectedSuggestion = null;
    ref
        .read(ingredientPortionSuggestionsProvider.notifier)
        .setSuggestions(portions ?? _barcodeOutcome?.portions ?? const []);
    final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
    ingredientDraft.overrideDraft(
      scannedIngredient.copyWith(
        barcode: scannedIngredient.barcode ?? _pendingBarcode,
      ),
    );
    ref.invalidate(ingredientFormKeyProvider);
    _moveTo(
      AddMealIngredientStage.ingredientForm,
      backTo: AddMealIngredientStage.ingredientSearch,
    );
  }

  void continuePhotoSearchAsFullScan() {
    _usesCreationMenu = true;
    _creatingManually = false;
    ref.invalidate(ingredientPhotoScanControllerProvider);
    _moveTo(
      AddMealIngredientStage.ingredientPhotoScan,
      backTo: AddMealIngredientStage.ingredientSearch,
    );
  }

  Future<void> selectSuggestedPortion(RecognizedPortion suggestion) async {
    if (state != AddMealIngredientStage.portionAddNewSearch) return;
    final revision = _navigationRevision;
    _selectedSuggestion = suggestion;
    final selection = await ref
        .read(ingredientPortionsUseCaseProvider)
        .fromSuggestion(suggestion);
    if (!ref.mounted ||
        revision != _navigationRevision ||
        state != AddMealIngredientStage.portionAddNewSearch) {
      return;
    }
    ref.read(portionDraftProvider.notifier).overrideDraft(selection);
    if (selection.map(
      existing: (_) => true,
      draft: (_) => false,
      empty: (_) => false,
    )) {
      await nextStage();
      return;
    }
    _moveTo(AddMealIngredientStage.portionAddNewForm);
  }

  Future<void> confirmNewPortion() async {
    if (state != AddMealIngredientStage.portionAddNewForm) return;
    final revision = _navigationRevision;
    final selection = ref.read(portionDraftProvider);
    final result = await ref
        .read(ingredientPortionsUseCaseProvider)
        .resolve(ref.read(mealIngredientsDraftProvider).ingredient, selection);
    if (!ref.mounted || revision != _navigationRevision) return;
    if (!result.exists) {
      await nextStage();
      return;
    }
    final resolved = result.selection;
    final weight = result.grams;
    ref.read(portionDraftProvider.notifier).overrideDraft(resolved);
    if (weight != null && weight > 0) {
      final draft = ref.read(mealIngredientsDraftProvider.notifier);
      draft.selectIngredientPortion(resolved);
      draft.setIngredientPortionAmount(weight);
      _openAmountForm(backTo: AddMealIngredientStage.definedPortionsSearch);
    } else {
      ref
          .read(mealIngredientsDraftProvider.notifier)
          .selectIngredientPortion(resolved);
      _prefillSuggestedPortionWeight(resolved);
      _moveTo(
        AddMealIngredientStage.portionSpecifyAmount,
        backTo: AddMealIngredientStage.portionAddNewSearch,
      );
    }
  }

  Future<void> nextStage() async {
    switch (state) {
      case AddMealIngredientStage.dismiss:
        throw UnimplementedError();
      case AddMealIngredientStage.ingredientCreationMethod:
        throw StateError('Choose how to create the ingredient first');
      case AddMealIngredientStage.ingredientSearch:
        final ingredientDraft = ref.read(ingredientDraftProvider);
        _continueWithSelectedIngredientDraft(ingredientDraft);
        break;
      case AddMealIngredientStage.ingredientPhotoScan:
        final request = ++_photoScanRequest;
        final photos = ref.read(ingredientPhotoScanCaptureControllerProvider);
        if (identical(photos, _reviewedPhotos)) {
          _moveTo(AddMealIngredientStage.ingredientForm);
          break;
        }
        final scannedIngredient = await ref
            .read(ingredientPhotoScanControllerProvider.notifier)
            .scanIngredient();
        if (!ref.mounted ||
            state != AddMealIngredientStage.ingredientPhotoScan ||
            request != _photoScanRequest) {
          break;
        }
        if (scannedIngredient == null) {
          break;
        }
        final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
        ingredientDraft.overrideDraft(
          scannedIngredient.copyWith(
            barcode: scannedIngredient.barcode ?? _pendingBarcode,
          ),
        );
        _reviewedPhotos = photos;
        _capturePhotoSuggestions();
        ref.invalidate(ingredientFormKeyProvider);
        _moveTo(
          AddMealIngredientStage.ingredientForm,
          backTo: _usesCreationMenu
              ? AddMealIngredientStage.ingredientPhotoScan
              : AddMealIngredientStage.ingredientSearch,
        );
        break;
      case AddMealIngredientStage.ingredientForm:
      case AddMealIngredientStage.referenceIngredientForm:
        var ingredientDraft = ref.read(ingredientDraftProvider);
        if (_creatingManually) _manualDraft = ingredientDraft;
        if (state == AddMealIngredientStage.referenceIngredientForm &&
            !_editingReference) {
          _referenceDraft = ingredientDraft;
        }
        if (_editingReference &&
            ingredientDraft != _originalReference &&
            ingredientDraft.getIngredientIdOrNull() != null) {
          ingredientDraft = ingredientDraft.asNewDraft();
          ref
              .read(ingredientDraftProvider.notifier)
              .overrideDraft(ingredientDraft);
        }
        final mealIngredientsDraft = ref.watch(
          mealIngredientsDraftProvider.notifier,
        );
        mealIngredientsDraft.setIngredient(ingredientDraft);
        prefetchIngredientIcon(ref, ingredientDraft);
        if (ingredientDraft.isReference) {
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
          if (_editingReference) {
            _editingReference = false;
            back();
          } else {
            _openAmountForm();
          }
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
        _prefillSuggestedPortionWeight(portionsDraft);
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
        completeAmountForm();
        _moveTo(AddMealIngredientStage.summary);
        break;
      case AddMealIngredientStage.summary:
        throw StateError('Complete the summary to finish adding an ingredient');
    }
  }

  MealIngredientsDraft completeAmountForm() {
    if (state != AddMealIngredientStage.amountForm &&
        state != AddMealIngredientStage.summary) {
      throw StateError('The amount form must be open before completing it');
    }
    final amount = ref.read(mealIngredientAmountDraftProvider);
    if (amount <= 0 || !amount.isFinite) {
      throw StateError(
        'Ingredient amount must be finite and greater than zero',
      );
    }
    final reviewed = ref.read(mealIngredientsDraftProvider);
    final hasSelectedPortion = reviewed.ingredientPortion.portion.maybeMap(
      existing: (_) => true,
      orElse: () => false,
    );
    if (!reviewed.ingredient.isReference && hasSelectedPortion && reviewed.ingredientPortion.amount <= 0) {
      final weight = ref.read(gramsPerPortionProvider(reviewed.ingredient, reviewed.ingredientPortion.portion)).asData?.value;
      if (weight == null || !weight.isFinite || weight <= 0) {
        throw StateError('The selected portion weight is not ready for review');
      }
      ref.read(mealIngredientsDraftProvider.notifier).setIngredientPortionAmount(weight);
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
      case AddMealIngredientStage.ingredientCreationMethod:
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
      case AddMealIngredientStage.referenceIngredientForm:
        _moveTo(AddMealIngredientStage.ingredientSearch);
        break;
      case AddMealIngredientStage.portionAddNewSearch:
        ref.invalidate(portionDraftProvider);
        ref.read(portionDraftProvider.notifier).setUnitHint('g');
        _moveTo(AddMealIngredientStage.portionAddNewForm);
        break;
      case AddMealIngredientStage.amountForm:
      case AddMealIngredientStage.summary:
      case AddMealIngredientStage.portionSpecifyAmount:
        throw UnimplementedError();
    }
  }

  void continueWithIngredientScanReview() {
    final scannedIngredient = ref
        .read(ingredientPhotoScanControllerProvider.notifier)
        .draftFromCurrentResult();
    if (scannedIngredient == null) {
      return;
    }

    final ingredientDraft = ref.read(ingredientDraftProvider.notifier);
    ingredientDraft.overrideDraft(
      scannedIngredient.copyWith(
        barcode: scannedIngredient.barcode ?? _pendingBarcode,
      ),
    );
    _reviewedPhotos = ref.read(ingredientPhotoScanCaptureControllerProvider);
    _capturePhotoSuggestions();
    ref.invalidate(ingredientFormKeyProvider);
    _moveTo(
      AddMealIngredientStage.ingredientForm,
      backTo: _usesCreationMenu
          ? AddMealIngredientStage.ingredientPhotoScan
          : AddMealIngredientStage.ingredientSearch,
    );
  }

  void back() {
    _navigationRevision++;
    if (state == AddMealIngredientStage.ingredientPhotoScan) {
      _photoScanRequest++;
    }
    if (state == AddMealIngredientStage.ingredientForm && _creatingManually) {
      _manualDraft = ref.read(ingredientDraftProvider);
    }
    if (state == AddMealIngredientStage.referenceIngredientForm) {
      if (!_editingReference) {
        _referenceDraft = ref.read(ingredientDraftProvider);
      }
      if (_editingReference && _originalReference != null) {
        ref
            .read(ingredientDraftProvider.notifier)
            .overrideDraft(_originalReference!);
      }
      _editingReference = false;
    }
    state = _history.pop();
    final ingredientId = ref
        .read(mealIngredientsDraftProvider)
        .ingredient
        .getIngredientIdOrNull();
    if (state == AddMealIngredientStage.definedPortionsSearch &&
        ingredientId != null) {
      ref
          .read(portionFilterProvider.notifier)
          .setFilter(
            PortionFilter.byQueryForIngredient(ingredientId: ingredientId),
          );
    } else if (state == AddMealIngredientStage.portionAddNewSearch) {
      ref
          .read(portionFilterProvider.notifier)
          .setFilter(
            ingredientId == null
                ? const PortionFilter.byQuery()
                : PortionFilter.allUnassignedForIngredient(
                    ingredientId: ingredientId,
                  ),
          );
    }
  }

  void _moveTo(AddMealIngredientStage next, {AddMealIngredientStage? backTo}) {
    _navigationRevision++;
    _history.push(backTo ?? state);
    state = next;
  }

  void _capturePhotoSuggestions() {
    _selectedSuggestion = null;
    final result = ref.read(ingredientPhotoScanControllerProvider).value;
    ref
        .read(ingredientPortionSuggestionsProvider.notifier)
        .setSuggestions(result?.portions ?? const []);
  }

  void _prefillSuggestedPortionWeight(PortionSelection portion) {
    final name = portion.map(
      draft: (value) => value.name,
      existing: (value) => value.name,
      empty: (_) => '',
    );
    final suggestions = [
      if (_selectedSuggestion != null) _selectedSuggestion!,
      ...ref.read(ingredientPortionSuggestionsProvider),
    ];
    for (final suggestion in suggestions) {
      final grams = suggestion.grams;
      if (namesMatchPortionSuggestion(name, suggestion.name ?? '') &&
          grams != null &&
          grams.isFinite &&
          grams > 0) {
        ref
            .read(mealIngredientsDraftProvider.notifier)
            .setIngredientPortionAmount(grams);
        return;
      }
    }
  }

  void _continueWithSelectedIngredientDraft(IngredientDraft ingredientDraft) {
    ref.read(ingredientPortionSuggestionsProvider.notifier).clear();
    _selectedSuggestion = null;
    _pendingBarcode = null;
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientsDraft.setIngredient(ingredientDraft);
    prefetchIngredientIcon(ref, ingredientDraft);
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
    _navigationRevision++;
    _history.reset();
    state = stage;
  }

  void _openAmountForm({AddMealIngredientStage? backTo}) {
    final draft = ref.read(mealIngredientsDraftProvider);
    final portion = draft.ingredientPortion.portion;
    if (portion != const PortionSelection.empty() &&
        draft.ingredientPortion.amount > 0) {
      _inlinePortionWeights[portion] = draft.ingredientPortion.amount;
    }
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

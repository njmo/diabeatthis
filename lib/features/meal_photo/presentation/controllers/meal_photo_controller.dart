import 'package:flutter/foundation.dart';

import '../../../../common/ai/ai_response_diagnostics.dart';
import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../domain/models/accepted_meal_photo_review.dart';
import '../../domain/models/meal_photo_candidate.dart';
import '../../domain/models/meal_photo_clarification_required.dart';
import '../../domain/models/meal_photo_input.dart';
import '../../domain/models/meal_photo_item.dart';
import '../../domain/models/meal_photo_model_response.dart';
import '../../domain/models/meal_photo_nutrition.dart';
import '../../domain/models/meal_photo_proposal.dart';
import '../../domain/models/meal_photo_proposal_stage.dart';
import '../../domain/models/meal_photo_review_item.dart';
import '../../domain/ports/meal_photo_meal_saver.dart';
import '../../domain/use_cases/find_meal_photo_product_use_case.dart';
import '../../domain/use_cases/propose_meal_from_photo_use_case.dart';
import '../../domain/use_cases/validate_meal_photo_review_use_case.dart';
import 'meal_photo_failure_diagnostics.dart';
import 'meal_photo_state.dart';

class MealPhotoController extends ChangeNotifier {
  MealPhotoController({
    required this.propose,
    required this.saver,
    this.checkIngredientCreation,
    this.validate = const ValidateMealPhotoReviewUseCase(),
  });
  final ProposeMealFromPhotoUseCase propose;
  final MealPhotoMealSaver saver;
  final Future<bool?> Function(MealPhotoReviewItem)? checkIngredientCreation;
  final ValidateMealPhotoReviewUseCase validate;
  MealPhotoState state = MealPhotoState();
  int revision = 0;
  int manualIngredientCounter = 0;
  String? editedMealName;
  String get mealName => editedMealName ?? state.proposal?.name ?? '';

  void renameMeal(String name) {
    requireEditable();
    final trimmed = name.trim();
    if (state.proposal == null ||
        state.loading ||
        trimmed.isEmpty ||
        trimmed.length > 120) {
      throw ArgumentError(
        'A meal name between 1 and 120 characters is required',
      );
    }
    editedMealName = trimmed;
    revision++;
    notifyListeners();
  }

  final Set<String> noProductMatches = {};
  final Set<String> excludedItemIds = {};
  bool disposed = false;
  final List<MealPhotoModelResponse> _responses = [];
  List<MealPhotoModelResponse> get responses => List.unmodifiable(_responses);
  Future<int>? pendingSave;
  void emit(MealPhotoState value) {
    if (disposed) return;
    state = value;
    notifyListeners();
  }

  Future<void> generate(
    MealPhotoInput input, {
    required String languageCode,
  }) async {
    if (pendingSave != null) throw StateError('Save is in progress');
    final token = ++revision;
    final requestId = '${DateTime.now().microsecondsSinceEpoch}-$token';
    editedMealName = null;
    _responses.clear();
    noProductMatches.clear();
    excludedItemIds.clear();
    final elapsed = Stopwatch()..start();
    emit(MealPhotoState(loading: true));
    recordMealPhotoDiagnostic('generation started');
    try {
      final result = await propose(
        input,
        languageCode: languageCode,
        onModelResponse: (response) {
          if (token != revision || disposed) return;
          _responses.add(response);
          printAiResponseDiagnostic(
            tag: 'MealPhotoResponse',
            requestId: requestId,
            stage: response.stage.name,
            response: response.text,
          );
          notifyListeners();
        },
        onProgress: (stage) {
          if (token != revision || disposed) return;
          recordMealPhotoDiagnostic(
            'stage=${stage.name} elapsedMs=${elapsed.elapsedMilliseconds}',
          );
          emit(MealPhotoState(loading: true, progress: stage));
        },
      );
      if (token != revision || disposed) return;
      recordMealPhotoDiagnostic(
        'generation completed elapsedMs=${elapsed.elapsedMilliseconds}',
      );
      emit(MealPhotoState(step: MealPhotoStep.mode, proposal: result));
    } on MealPhotoClarificationRequired catch (clarification) {
      if (token == revision && !disposed) {
        recordMealPhotoDiagnostic(
          'clarification=${clarification.reason.name} elapsedMs=${elapsed.elapsedMilliseconds}',
        );
        emit(MealPhotoState(clarification: clarification));
      }
    } catch (error, stack) {
      if (token == revision && !disposed) {
        printAiResponseDiagnostic(
          tag: 'MealPhotoFailure',
          requestId: requestId,
          stage: state.progress?.name ?? 'starting',
          response: error.toString(),
        );
        if (error is LlmOutputLimitException) {
          printAiResponseDiagnostic(
            tag: 'MealPhotoResponse',
            requestId: requestId,
            stage: 'truncated',
            response: error.response,
          );
          _responses.add(
            MealPhotoModelResponse(
              stage: state.progress == MealPhotoProposalStage.resolving
                  ? MealPhotoResponseStage.resolution
                  : MealPhotoResponseStage.description,
              text: error.response,
              truncated: true,
            ),
          );
        }
        recordMealPhotoDiagnostic(
          'generation failed stage=${state.progress?.name ?? "starting"} elapsedMs=${elapsed.elapsedMilliseconds} reason=${describeMealPhotoFailure(error)}',
          failed: true,
          stackTrace: stack,
        );
        emit(MealPhotoState(error: error, progress: state.progress));
      }
    }
  }

  void acceptWholePlateProposal() {
    // Ignore a repeated callback from a preview that already advanced.
    if (state.step != MealPhotoStep.mode) return;
    requireEditable();
    final proposal = state.proposal;
    if (proposal == null) throw StateError('No proposal');
    final reusable =
        state.mode == MealPhotoMode.reference &&
        state.items.length == 1 &&
        identical(state.items.single.proposal, proposal.reference) &&
        state.items.single.referenceAccepted &&
        state.items.single.product == null;
    if (reusable) {
      revision++;
      emit(
        MealPhotoState(
          step: MealPhotoStep.amounts,
          proposal: proposal,
          mode: MealPhotoMode.reference,
          items: state.items,
        ),
      );
      return;
    }
    chooseMode(MealPhotoMode.reference);
    acceptReference(proposal.reference.id);
    next();
  }

  void editWholePlateReference(
    MealPhotoNutrition nutrition, {
    double confidence = .3,
  }) {
    requireEditable();
    if (state.step != MealPhotoStep.mode || state.proposal == null) {
      throw StateError('Whole plate can only be edited from its preview');
    }
    final proposal = state.proposal!;
    final existing =
        state.mode == MealPhotoMode.reference &&
            state.items.length == 1 &&
            identical(state.items.single.proposal, proposal.reference)
        ? state.items.single
        : MealPhotoReviewItem.fromProposal(proposal.reference);
    final edited = existing.withManualReference(
      nutrition,
      confidence: confidence,
    );
    revision++;
    emit(
      MealPhotoState(
        step: MealPhotoStep.mode,
        proposal: proposal,
        mode: MealPhotoMode.reference,
        items: [edited],
      ),
    );
  }

  void chooseMode(MealPhotoMode mode) {
    requireEditable();
    final proposal = state.proposal;
    if (proposal == null) throw StateError('No proposal');
    revision++;
    emit(
      MealPhotoState(
        step: MealPhotoStep.assignment,
        proposal: proposal,
        mode: mode,
        items:
            mode == MealPhotoMode.reference &&
                state.mode == mode &&
                state.items.length == 1 &&
                identical(state.items.single.proposal, proposal.reference)
            ? state.items
            : proposal
                  .itemsFor(mode)
                  .where(
                    (item) =>
                        mode != MealPhotoMode.itemized ||
                        !excludedItemIds.contains(item.id),
                  )
                  .map(MealPhotoReviewItem.fromProposal)
                  .toList(),
      ),
    );
  }

  Future<void> divideIntoIngredients({required String languageCode}) async {
    if (state.step != MealPhotoStep.mode || state.loading) return;
    if (state.mode == MealPhotoMode.itemized) {
      revision++;
      emit(
        MealPhotoState(
          step: MealPhotoStep.assignment,
          proposal: state.proposal,
          mode: state.mode,
          items: state.items,
        ),
      );
      return;
    }
    chooseMode(MealPhotoMode.itemized);
    final token = revision;
    final proposal = state.proposal!;
    final items = state.items;
    emit(
      MealPhotoState(
        step: MealPhotoStep.assignment,
        proposal: proposal,
        mode: MealPhotoMode.itemized,
        items: items,
        loading: true,
        progress: MealPhotoProposalStage.findingProducts,
      ),
    );
    try {
      final find = FindMealPhotoProductUseCase(propose.candidates);
      final resolved = await Future.wait(
        items.map((item) async {
          final product = await find(item.proposal, languageCode: languageCode);
          return product != null
              ? item.assign(product, method: MealPhotoSelectionMethod.automatic)
              : item.referenceNutrition != null
              ? item.acceptReference(method: MealPhotoSelectionMethod.automatic)
              : item;
        }),
      );
      if (disposed || revision != token) return;
      noProductMatches
        ..clear()
        ..addAll(
          resolved
              .where((item) => item.product == null)
              .map((item) => item.proposal.id),
        );
      emit(
        MealPhotoState(
          step: MealPhotoStep.assignment,
          proposal: proposal,
          mode: MealPhotoMode.itemized,
          items: resolved,
        ),
      );
    } catch (error) {
      if (disposed || revision != token) return;
      emit(
        MealPhotoState(
          step: MealPhotoStep.assignment,
          proposal: proposal,
          mode: MealPhotoMode.itemized,
          items: items,
          error: error,
        ),
      );
    }
  }

  void addIngredient({
    MealPhotoCandidate? product,
    String? name,
    MealPhotoNutrition? nutrition,
    double confidence = .25,
  }) {
    requireEditable();
    if (state.mode != MealPhotoMode.itemized ||
        state.proposal == null ||
        (state.step != MealPhotoStep.assignment &&
            state.step != MealPhotoStep.amounts)) {
      throw StateError(
        'Ingredients can only be added during ingredient review',
      );
    }
    final ingredientName = product?.name ?? name?.trim();
    if (ingredientName == null ||
        ingredientName.isEmpty ||
        (product == null && nutrition == null)) {
      throw ArgumentError('A product or named reference nutrition is required');
    }
    nutrition?.validate();
    final original = state.proposal!;
    String id;
    do {
      id = 'manual_${++manualIngredientCounter}';
    } while (original.itemized.any((item) => item.id == id));
    final source = MealPhotoItem(
      id: id,
      name: ingredientName,
      searchQuery: ingredientName,
      kind: product != null
          ? MealPhotoItemKind.matched
          : MealPhotoItemKind.proposedReference,
      recognitionConfidence: .95,
      quantityConfidence: .25,
      nutritionConfidence: product?.effectiveNutritionConfidence ?? confidence,
      candidate: product,
      referenceNutrition: product == null ? nutrition : null,
    );
    final added = product != null
        ? MealPhotoReviewItem.fromProposal(source).assign(product)
        : MealPhotoReviewItem.fromProposal(
            source,
          ).withManualReference(nutrition!, confidence: confidence);
    revision++;
    emit(
      MealPhotoState(
        step: MealPhotoStep.assignment,
        mode: MealPhotoMode.itemized,
        proposal: MealPhotoProposal(
          name: original.name,
          itemized: [...original.itemized, source],
          reference: original.reference,
          rawResponse: original.rawResponse,
        ),
        items: [added, ...state.items],
      ),
    );
  }

  void removeIngredient(String id) {
    requireEditable();
    if (state.mode != MealPhotoMode.itemized ||
        (state.step != MealPhotoStep.assignment &&
            state.step != MealPhotoStep.amounts) ||
        !state.items.any((item) => item.proposal.id == id)) {
      throw StateError('Cannot remove this component');
    }
    excludedItemIds.add(id);
    revision++;
    emit(
      MealPhotoState(
        step: state.step,
        proposal: state.proposal,
        mode: state.mode,
        items: state.items.where((item) => item.proposal.id != id).toList(),
      ),
    );
  }

  void restoreIngredient(MealPhotoReviewItem item, int index) {
    requireEditable();
    if (state.mode != MealPhotoMode.itemized ||
        (state.step != MealPhotoStep.assignment &&
            state.step != MealPhotoStep.amounts) ||
        !excludedItemIds.contains(item.proposal.id) ||
        !state.proposal!.itemized.any(
          (source) => identical(source, item.proposal),
        )) {
      return;
    }
    final restored = [...state.items]
      ..insert(index.clamp(0, state.items.length), item);
    excludedItemIds.remove(item.proposal.id);
    revision++;
    emit(
      MealPhotoState(
        step: state.step,
        proposal: state.proposal,
        mode: state.mode,
        items: restored,
      ),
    );
  }

  void setManualReference(
    String id,
    MealPhotoNutrition nutrition, {
    double confidence = .3,
  }) => update(
    id,
    (item) => item.withManualReference(nutrition, confidence: confidence),
    assignmentChanged: true,
  );

  void assignProduct(String itemId, MealPhotoCandidate product) {
    if (state.mode == MealPhotoMode.reference) {
      throw StateError('Whole-plate reference cannot be replaced by a product');
    }
    update(itemId, (item) => item.assign(product), assignmentChanged: true);
  }

  void acceptReference(String itemId) =>
      update(itemId, (item) => item.acceptReference(), assignmentChanged: true);
  void setAmount(
    String itemId, {
    required double grams,
    required double quantityConfidence,
    required double nutritionConfidence,
    required bool reviewed,
  }) => update(
    itemId,
    (item) => item.adjust(
      grams: grams,
      quantityConfidence: quantityConfidence,
      nutritionConfidence: nutritionConfidence,
      reviewed: reviewed,
    ),
  );
  void update(
    String id,
    MealPhotoReviewItem Function(MealPhotoReviewItem) change, {
    bool assignmentChanged = false,
  }) {
    requireEditable();
    if (!state.items.any((item) => item.proposal.id == id)) {
      throw StateError('Unknown component');
    }
    revision++;
    emit(
      MealPhotoState(
        step: assignmentChanged
            ? MealPhotoStep.assignment
            : state.step == MealPhotoStep.confirmation
            ? MealPhotoStep.amounts
            : state.step,
        proposal: state.proposal,
        mode: state.mode,
        items: state.items
            .map((item) => item.proposal.id == id ? change(item) : item)
            .toList(),
      ),
    );
  }

  void next() {
    requireEditable();
    final step = switch (state.step) {
      MealPhotoStep.assignment when state.allReviewed =>
        MealPhotoStep.confirmation,
      MealPhotoStep.assignment when state.allAssigned => MealPhotoStep.amounts,
      MealPhotoStep.amounts when state.allReviewed =>
        MealPhotoStep.confirmation,
      _ => throw StateError('Complete the current review step'),
    };
    if (step == MealPhotoStep.confirmation) validate(review());
    revision++;
    emit(
      MealPhotoState(
        step: step,
        proposal: state.proposal,
        mode: state.mode,
        items: state.items,
      ),
    );
  }

  void back() {
    requireEditable();
    final step = switch (state.step) {
      MealPhotoStep.mode => MealPhotoStep.capture,
      MealPhotoStep.assignment => MealPhotoStep.mode,
      MealPhotoStep.amounts => MealPhotoStep.mode,
      MealPhotoStep.confirmation => MealPhotoStep.amounts,
      _ => throw StateError('Cannot go back'),
    };
    revision++;
    emit(
      MealPhotoState(
        step: step,
        proposal: state.proposal,
        mode: state.mode,
        items: state.items,
      ),
    );
  }

  AcceptedMealPhotoReview review() => AcceptedMealPhotoReview(
    name: mealName,
    mode: state.mode,
    items: state.items,
    proposalResponse: state.proposal!.rawResponse,
    sourceProposal: state.proposal!,
    excludedItemIds: state.mode == MealPhotoMode.itemized
        ? excludedItemIds
        : const {},
  );
  Future<int> save({required bool confirmed}) {
    if (pendingSave != null) return pendingSave!;
    if (state.savedMealId != null) return Future.value(state.savedMealId!);
    if (!confirmed || state.step != MealPhotoStep.confirmation) {
      throw StateError('Explicit final confirmation required');
    }
    final accepted = review();
    validate(accepted);
    final token = revision;
    emit(
      MealPhotoState(
        step: state.step,
        proposal: state.proposal,
        mode: state.mode,
        items: state.items,
        saving: true,
      ),
    );
    final future = Future<int>.sync(() => saver.save(accepted)).then(
      (id) {
        if (token == revision && !disposed) {
          emit(
            MealPhotoState(
              step: MealPhotoStep.saved,
              proposal: state.proposal,
              mode: state.mode,
              items: state.items,
              savedMealId: id,
            ),
          );
        }
        return id;
      },
      onError: (Object error, StackTrace stack) {
        if (token == revision && !disposed) {
          emit(
            MealPhotoState(
              step: MealPhotoStep.confirmation,
              proposal: state.proposal,
              mode: state.mode,
              items: state.items,
              error: error,
            ),
          );
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
    pendingSave = future;
    future.then(
      (_) {
        pendingSave = null;
      },
      onError: (Object _, StackTrace __) {
        pendingSave = null;
      },
    );
    return future;
  }

  void reportReviewError(Object error) {
    emit(
      MealPhotoState(
        step: state.step,
        proposal: state.proposal,
        mode: state.mode,
        items: state.items,
        error: error,
      ),
    );
  }

  void requireEditable() {
    if (state.loading ||
        state.saving ||
        state.step == MealPhotoStep.saved ||
        disposed) {
      throw StateError('Review is not editable');
    }
  }

  void cancel() {
    if (pendingSave != null || state.saving) {
      throw StateError('Cannot cancel while saving');
    }
    revision++;
    editedMealName = null;
    _responses.clear();
    emit(MealPhotoState());
  }

  @override
  void dispose() {
    disposed = true;
    editedMealName = null;
    _responses.clear();
    revision++;
    super.dispose();
  }
}

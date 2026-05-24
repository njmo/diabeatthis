import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../dashboard/data/providers/device_status_ui_provider.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../data/mappers/quick_low_treatment_item_mapper.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../../domain/use_cases/add_low_treatment_context_entry_use_case.dart';

part 'low_treatment_context_controller.g.dart';

@riverpod
class LowTreatmentContextController extends _$LowTreatmentContextController {
  static const _relatedMealAutoAttachWindow = Duration(hours: 3);

  late AddMealUseCase _addMealUseCase;
  late AddLowTreatmentContextEntryUseCase _addContextUseCase;

  @override
  LowTreatmentSheetState build() {
    _addMealUseCase = ref.watch(addMealUseCaseProvider);
    _addContextUseCase = ref.watch(addLowTreatmentContextEntryUseCaseProvider);

    final deviceStatus = ref.read(deviceStatusUiProvider);
    final hasAapsSuggestion = (deviceStatus?.carbsReq ?? 0) > 0;
    final reason = hasAapsSuggestion
        ? LowTreatmentReason.carbsReq
        : LowTreatmentReason.lowGlucose;

    unawaited(Future<void>.microtask(_attachRecentRelatedMeal));

    return LowTreatmentSheetState(
      contextDraft: composeDraft(
        meal: MealDraft(
          name: 'Dosłodzenie',
          mealIngredients: const [],
          plannedAt: clock.now(),
          purpose: MealPurpose.lowTreatment,
          status: 'confirmed',
        ),
        source: LowTreatmentContextSource.dashboardAction,
        deviceStatus: deviceStatus,
        reason: reason,
      ),
    );
  }

  LowTreatmentContextDraft composeDashboardDraft({
    required MealDraft meal,
    int? relatedMealId,
  }) {
    final deviceStatus = ref.read(deviceStatusUiProvider);
    return composeDraft(
      meal: meal,
      relatedMealId: relatedMealId,
      source: LowTreatmentContextSource.dashboardAction,
      deviceStatus: deviceStatus,
      reason: _defaultReason(deviceStatus),
    );
  }

  LowTreatmentContextDraft composeDraft({
    required MealDraft meal,
    int? relatedMealId,
    required LowTreatmentContextSource source,
    DeviceStatus? deviceStatus,
    required LowTreatmentReason reason,
  }) {
    final activeSuggestion = _activeSuggestion(deviceStatus);

    return LowTreatmentContextDraft(
      meal: meal.copyWith(purpose: MealPurpose.lowTreatment),
      relatedMealId: relatedMealId,
      source: source,
      suggestedCarbs: activeSuggestion?.carbsReq,
      suggestedWithinMinutes: activeSuggestion?.carbsReqWithin,
      suggestionAt: activeSuggestion?.date ?? clock.now(),
      deviceStatusDate: activeSuggestion?.date,
      reason: reason,
    );
  }

  void setReason(LowTreatmentReason reason) {
    final contextDraft = state.contextDraft.copyWith(reason: reason);

    state = state.copyWith(contextDraft: contextDraft);
  }

  void detachRelatedMeal() {
    state = state.copyWith(
      contextDraft: state.contextDraft.copyWith(relatedMealId: null),
      clearRelatedMeal: true,
      relatedMealAutoAttachEnabled: false,
    );
  }

  void addMealIngredient(MealIngredientsDraft mealIngredient) {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: [...meal.mealIngredients, mealIngredient],
      );
    });

    state = state.copyWith(contextDraft: contextDraft);
  }

  void clearMealIngredients() {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(mealIngredients: const []);
    });

    state = state.copyWith(contextDraft: contextDraft);
  }

  void setQuickLowTreatmentItem(
    QuickLowTreatmentItem item, [
    int quantity = 1,
  ]) {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: [item.toMealIngredientDraft(quantity: quantity)],
      );
    });

    state = state.copyWith(contextDraft: contextDraft);
  }

  void updateMealIngredient(
    MealIngredientsDraft oldMealIngredient,
    MealIngredientsDraft newMealIngredient,
  ) {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: meal.mealIngredients.map((mealIngredient) {
          if (mealIngredient == oldMealIngredient) {
            return newMealIngredient;
          }
          return mealIngredient;
        }).toList(),
      );
    });

    state = state.copyWith(contextDraft: contextDraft);
  }

  void removeMealIngredient(MealIngredientsDraft mealIngredient) {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: meal.mealIngredients
            .where((element) => element != mealIngredient)
            .toList(),
      );
    });

    state = state.copyWith(contextDraft: contextDraft);
  }

  Future<LowTreatmentContext> save(LowTreatmentContextDraft draft) async {
    if (draft.mealId != null) {
      return _saveContext(draft, mealId: draft.mealId!);
    }

    final db = ref.read(databaseProvider);
    final result = await db.transaction(() async {
      final mealDraft = draft.meal.copyWith(plannedAt: clock.now());
      final mealId = await _createLowTreatmentMeal(mealDraft);
      final contextDraft = draft.copyWith(mealId: mealId, meal: mealDraft);
      final context = await _saveContext(contextDraft, mealId: mealId);

      return (context: context, contextDraft: contextDraft);
    });

    if (state.contextDraft == draft) {
      state = state.copyWith(contextDraft: result.contextDraft);
    }

    return result.context;
  }

  Future<LowTreatmentContext> saveCurrentDraft() async {
    if (state.isSaving) {
      throw StateError('Low treatment save is already in progress.');
    }

    state = state.copyWith(isSaving: true);
    try {
      await _attachRecentRelatedMeal();
      return await save(state.contextDraft);
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  LowTreatmentContextDraft _updateDraftMeal(
    MealDraft Function(MealDraft meal) update,
  ) {
    return state.contextDraft.copyWith(meal: update(state.contextDraft.meal));
  }

  Future<int> _createLowTreatmentMeal(MealDraft mealDraft) async {
    final meal = await _addMealUseCase.call(_lowTreatmentMealDraft(mealDraft));
    return meal.id;
  }

  Future<void> _attachRecentRelatedMeal() async {
    if (!ref.mounted) {
      return;
    }

    if (!state.relatedMealAutoAttachEnabled ||
        state.contextDraft.relatedMealId != null) {
      return;
    }

    final db = ref.read(databaseProvider);
    final meal = await db.mealDao.getLatestMealBefore(
      clock.now(),
      maxAge: _relatedMealAutoAttachWindow,
    );
    if (!ref.mounted || meal == null) {
      return;
    }

    if (!state.relatedMealAutoAttachEnabled ||
        state.contextDraft.relatedMealId != null) {
      return;
    }

    final relatedMeal = meal.toDomain();
    state = state.copyWith(
      contextDraft: state.contextDraft.copyWith(relatedMealId: relatedMeal.id),
      relatedMeal: relatedMeal,
    );
  }

  Future<LowTreatmentContext> _saveContext(
    LowTreatmentContextDraft draft, {
    required int mealId,
  }) {
    return _addContextUseCase.call(draft, mealId: mealId);
  }

  MealDraft _lowTreatmentMealDraft(MealDraft meal) {
    return meal.copyWith(purpose: MealPurpose.lowTreatment);
  }

  DeviceStatus? _activeSuggestion(DeviceStatus? deviceStatus) {
    if (deviceStatus == null || deviceStatus.carbsReq <= 0) {
      return null;
    }
    return deviceStatus;
  }

  LowTreatmentReason _defaultReason(DeviceStatus? deviceStatus) {
    return _activeSuggestion(deviceStatus) == null
        ? LowTreatmentReason.lowGlucose
        : LowTreatmentReason.carbsReq;
  }
}

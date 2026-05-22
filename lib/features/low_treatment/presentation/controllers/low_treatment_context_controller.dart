import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../foreground/providers/device_status_value_provider.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../data/mappers/quick_low_treatment_item_mapper.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../../domain/use_cases/add_low_treatment_context_entry_use_case.dart';

part 'low_treatment_context_controller.g.dart';

@riverpod
class LowTreatmentContextController extends _$LowTreatmentContextController {
  late AddMealUseCase _addMealUseCase;
  late AddLowTreatmentContextEntryUseCase _addContextUseCase;

  @override
  LowTreatmentSheetState build() {
    _addMealUseCase = ref.watch(addMealUseCaseProvider);
    _addContextUseCase = ref.watch(addLowTreatmentContextEntryUseCaseProvider);

    final deviceStatus = ref.read(deviceStatusValueProvider);
    final hasAapsSuggestion = (deviceStatus?.carbsReq ?? 0) > 0;
    final reason = hasAapsSuggestion
        ? LowTreatmentReason.carbsReq
        : LowTreatmentReason.lowGlucose;

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
    final deviceStatus = ref.read(deviceStatusValueProvider);
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
      meal: meal.copyWith(
        purpose: MealPurpose.lowTreatment,
        status: meal.status == 'draft' ? 'confirmed' : meal.status,
      ),
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

  void addMealIngredient(MealIngredientsDraft mealIngredient) {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: [...meal.mealIngredients, mealIngredient],
      );
    });

    state = state.copyWith(contextDraft: contextDraft);
  }

  void setQuickLowTreatmentItem(QuickLowTreatmentItem item) {
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(mealIngredients: [item.toMealIngredientDraft()]);
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

  Future<LowTreatmentContext> _saveContext(
    LowTreatmentContextDraft draft, {
    required int mealId,
  }) {
    return _addContextUseCase.call(draft, mealId: mealId);
  }

  MealDraft _lowTreatmentMealDraft(MealDraft meal) {
    return meal.copyWith(
      purpose: MealPurpose.lowTreatment,
      status: meal.status == 'draft' ? 'confirmed' : meal.status,
    );
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

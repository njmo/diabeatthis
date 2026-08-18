import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../../dashboard/data/providers/device_status_ui_provider.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../data/mappers/quick_low_treatment_item_mapper.dart';
import '../../data/models/low_treatment_related_record.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../../data/providers/low_treatment_related_activity_provider.dart';
import '../../data/providers/low_treatment_related_meal_provider.dart';
import '../../domain/use_cases/add_low_treatment_context_entry_use_case.dart';

part 'low_treatment_context_controller.g.dart';

@riverpod
class LowTreatmentContextController extends _$LowTreatmentContextController {
  late AddMealUseCase _addMealUseCase;
  late AddLowTreatmentContextEntryUseCase _addContextUseCase;

  @override
  Future<LowTreatmentSheetState> build() async {
    _addMealUseCase = ref.watch(addMealUseCaseProvider);
    _addContextUseCase = ref.watch(addLowTreatmentContextEntryUseCaseProvider);

    final deviceStatus = ref.read(deviceStatusUiProvider);
    final hasAapsSuggestion = (deviceStatus?.carbsReq ?? 0) > 0;
    final reason = hasAapsSuggestion
        ? LowTreatmentReason.carbsReq
        : LowTreatmentReason.lowGlucose;

    final initialState = LowTreatmentSheetState(
      contextDraft: composeDraft(
        meal: MealDraft(
          name: lang.lowTreatmentMealName,
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
    final relatedMeal = await ref.read(
      lowTreatmentRelatedMealCandidateProvider.future,
    );
    final relatedActivityLog = await ref.read(
      lowTreatmentRelatedActivityCandidateProvider.future,
    );

    return _stateWithRelatedCandidates(
      initialState,
      relatedMeal: relatedMeal,
      relatedActivityLog: relatedActivityLog,
    );
  }

  LowTreatmentContextDraft composeDashboardDraft({
    required MealDraft meal,
    int? relatedMealId,
    int? relatedActivityLogId,
  }) {
    final deviceStatus = ref.read(deviceStatusUiProvider);
    return composeDraft(
      meal: meal,
      relatedMealId: relatedMealId,
      relatedActivityLogId: relatedActivityLogId,
      source: LowTreatmentContextSource.dashboardAction,
      deviceStatus: deviceStatus,
      reason: _defaultReason(deviceStatus),
    );
  }

  LowTreatmentContextDraft composeDraft({
    required MealDraft meal,
    int? relatedMealId,
    int? relatedActivityLogId,
    required LowTreatmentContextSource source,
    DeviceStatus? deviceStatus,
    required LowTreatmentReason reason,
  }) {
    final activeSuggestion = _activeSuggestion(deviceStatus);

    return LowTreatmentContextDraft(
      meal: meal.copyWith(purpose: MealPurpose.lowTreatment),
      relatedMealId: relatedMealId,
      relatedActivityLogId: relatedActivityLogId,
      source: source,
      suggestedCarbs: activeSuggestion?.carbsReq,
      suggestedWithinMinutes: activeSuggestion?.carbsReqWithin,
      suggestionAt: activeSuggestion?.date ?? clock.now(),
      deviceStatusDate: activeSuggestion?.date,
      reason: reason,
    );
  }

  void setReason(LowTreatmentReason reason) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final contextDraft = current.contextDraft.copyWith(reason: reason);

    state = AsyncData(current.copyWith(contextDraft: contextDraft));
  }

  void switchRelatedContext() {
    final current = state.value;
    if (current == null) {
      return;
    }

    final currentRelatedRecord = current.selectedRelatedRecord;
    if (currentRelatedRecord == null) {
      return;
    }

    currentRelatedRecord.map(
      activity: (_) {
        final mealToSwitch = current.relatedMeal;
        if (mealToSwitch == null) {
          return;
        }

        state = AsyncData(
          current.copyWith(
            contextDraft: current.contextDraft.copyWith(
              relatedMealId: mealToSwitch.id,
              relatedActivityLogId: null,
            ),
            relatedMeal: mealToSwitch,
            relatedAutoAttachEnabled: false,
          ),
        );
      },
      meal: (_) {
        final activityToSwitch = current.relatedActivityLog;
        if (activityToSwitch == null) {
          return;
        }

        state = AsyncData(
          current.copyWith(
            contextDraft: current.contextDraft.copyWith(
              relatedMealId: null,
              relatedActivityLogId: activityToSwitch.id,
              reason: _activityReason(current.contextDraft.reason),
            ),
            relatedActivityLog: activityToSwitch,
            relatedAutoAttachEnabled: false,
          ),
        );
      },
    );
  }

  void addMealIngredient(MealIngredientsDraft mealIngredient) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: [...meal.mealIngredients, mealIngredient],
      );
    });

    state = AsyncData(current.copyWith(contextDraft: contextDraft));
  }

  void clearMealIngredients() {
    final current = state.value;
    if (current == null) {
      return;
    }
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(mealIngredients: const []);
    });

    state = AsyncData(current.copyWith(contextDraft: contextDraft));
  }

  void setQuickLowTreatmentItem(
    QuickLowTreatmentItem item, [
    int quantity = 1,
  ]) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: [item.toMealIngredientDraft(quantity: quantity)],
      );
    });

    state = AsyncData(current.copyWith(contextDraft: contextDraft));
  }

  void updateMealIngredient(
    MealIngredientsDraft oldMealIngredient,
    MealIngredientsDraft newMealIngredient,
  ) {
    final current = state.value;
    if (current == null) {
      return;
    }
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

    state = AsyncData(current.copyWith(contextDraft: contextDraft));
  }

  void removeMealIngredient(MealIngredientsDraft mealIngredient) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final contextDraft = _updateDraftMeal((meal) {
      return meal.copyWith(
        mealIngredients: meal.mealIngredients
            .where((element) => element != mealIngredient)
            .toList(),
      );
    });

    state = AsyncData(current.copyWith(contextDraft: contextDraft));
  }

  Future<LowTreatmentContext> save(LowTreatmentContextDraft draft) async {
    if (draft.mealId != null) {
      return _addContextUseCase.call(draft, mealId: draft.mealId!);
    }

    final db = ref.read(databaseProvider);
    final result = await db.transaction(() async {
      final mealDraft = draft.meal.copyWith(plannedAt: clock.now());
      final meal = await _addMealUseCase.call(
        mealDraft.copyWith(purpose: MealPurpose.lowTreatment),
      );
      final mealId = meal.id;
      final contextDraft = draft.copyWith(mealId: mealId, meal: mealDraft);
      final context = await _addContextUseCase.call(
        contextDraft,
        mealId: mealId,
      );

      return (context: context, contextDraft: contextDraft);
    });

    final current = state.value;
    if (current?.contextDraft == draft) {
      state = AsyncData(current!.copyWith(contextDraft: result.contextDraft));
    }

    return result.context;
  }

  Future<LowTreatmentContext> saveCurrentDraft() async {
    final current = state.value;
    if (current == null) {
      throw StateError('Low treatment draft is not ready.');
    }
    if (current.isSaving) {
      throw StateError('Low treatment save is already in progress.');
    }

    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final latest = state.value ?? current;
      return await save(latest.contextDraft);
    } finally {
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(isSaving: false));
      }
    }
  }

  LowTreatmentContextDraft _updateDraftMeal(
    MealDraft Function(MealDraft meal) update,
  ) {
    final current = state.value;
    if (current == null) {
      throw StateError('Low treatment draft is not ready.');
    }
    return current.contextDraft.copyWith(
      meal: update(current.contextDraft.meal),
    );
  }

  void detachRelatedContext() {
    final current = state.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        contextDraft: current.contextDraft.copyWith(
          relatedMealId: null,
          relatedActivityLogId: null,
        ),
        relatedAutoAttachEnabled: false,
      ),
    );
  }

  LowTreatmentSheetState _stateWithRelatedCandidates(
    LowTreatmentSheetState current, {
    required Meal? relatedMeal,
    required ActivityLogSummaryData? relatedActivityLog,
  }) {
    final meal = relatedMeal;
    final activityLog = relatedActivityLog;
    var contextDraft = current.contextDraft;

    if (contextDraft.relatedMealId != null &&
        contextDraft.relatedMealId != meal?.id) {
      contextDraft = contextDraft.copyWith(relatedMealId: null);
    }
    if (contextDraft.relatedActivityLogId != null &&
        contextDraft.relatedActivityLogId != activityLog?.id) {
      contextDraft = contextDraft.copyWith(relatedActivityLogId: null);
    }

    if (current.relatedAutoAttachEnabled &&
        contextDraft.relatedMealId == null &&
        contextDraft.relatedActivityLogId == null) {
      if (activityLog != null) {
        contextDraft = contextDraft.copyWith(
          relatedMealId: null,
          relatedActivityLogId: activityLog.id,
          reason: _activityReason(contextDraft.reason),
        );
      } else if (meal != null) {
        contextDraft = contextDraft.copyWith(
          relatedMealId: meal.id,
          relatedActivityLogId: null,
        );
      }
    }

    return current.copyWith(
      contextDraft: contextDraft,
      relatedMeal: meal,
      relatedActivityLog: activityLog,
      clearRelatedMeal: meal == null,
      clearRelatedActivityLog: activityLog == null,
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

  LowTreatmentReason _activityReason(LowTreatmentReason currentReason) {
    if (currentReason != LowTreatmentReason.lowGlucose) {
      return currentReason;
    }
    return LowTreatmentReason.plannedActivity;
  }
}

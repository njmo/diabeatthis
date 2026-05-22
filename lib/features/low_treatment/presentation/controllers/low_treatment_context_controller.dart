import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../foreground/providers/device_status_value_provider.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../data/models/low_treatment_sheet_state.dart';
import '../../domain/use_cases/add_low_treatment_context_entry_use_case.dart';

part 'low_treatment_context_controller.g.dart';

@riverpod
class LowTreatmentContextController extends _$LowTreatmentContextController {
  late AddMealUseCase _addMealUseCase;
  late AddLowTreatmentContextEntryUseCase _addContextUseCase;

  @override
  LowTreatmentSheetState build() {
    _addMealUseCase = ref.read(addMealUseCaseProvider);
    _addContextUseCase = ref.read(addLowTreatmentContextEntryUseCaseProvider);

    final deviceStatus = ref.read(deviceStatusValueProvider);
    final hasAapsSuggestion = (deviceStatus?.carbsReq ?? 0) > 0;
    final reason = hasAapsSuggestion
        ? LowTreatmentReason.carbsReq
        : LowTreatmentReason.lowGlucose;

    return LowTreatmentSheetState(
      contextDraft: composeDraft(
        meal: MealDraft(
          name: '',
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

    return LowTreatmentContextDraft.draft(
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

  void removeMealIngredient(MealIngredientsDraft mealIngredient) {
    final contextDraft = state.contextDraft.map(
      draft: (draft) {
        final meal = draft.meal.copyWith(
          mealIngredients: draft.meal.mealIngredients
              .where((element) => element != mealIngredient)
              .toList(),
        );
        return draft.copyWith(meal: meal);
      },
      existing: (_) {
        throw StateError(
          'Low treatment sheet does not support existing context editing yet.',
        );
      },
    );

    state = state.copyWith(contextDraft: contextDraft);
  }

  Future<LowTreatmentContext> save(LowTreatmentContextDraft draft) async {
    final mealId = await draft.map(
      draft: (draft) async {
        final meal = await _addMealUseCase.call(
          _lowTreatmentMealDraft(draft.meal),
        );
        return meal.id;
      },
      existing: (existing) async => existing.mealId,
    );

    return _addContextUseCase.call(draft, mealId: mealId);
  }

  Future<LowTreatmentContext> saveCurrentDraft() {
    return save(state.contextDraft);
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

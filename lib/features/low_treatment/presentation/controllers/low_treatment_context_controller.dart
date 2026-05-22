import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../foreground/providers/device_status_value_provider.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../domain/use_cases/add_low_treatment_context_entry_use_case.dart';

part 'low_treatment_context_controller.g.dart';

@riverpod
class LowTreatmentContextController extends _$LowTreatmentContextController {
  late AddMealUseCase _addMealUseCase;
  late AddLowTreatmentContextEntryUseCase _addContextUseCase;

  @override
  FutureOr<LowTreatmentContext?> build() {
    _addMealUseCase = ref.read(addMealUseCaseProvider);
    _addContextUseCase = ref.read(addLowTreatmentContextEntryUseCaseProvider);
    return null;
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
    );
  }

  LowTreatmentContextDraft composeDraft({
    required MealDraft meal,
    int? relatedMealId,
    required LowTreatmentContextSource source,
    DeviceStatus? deviceStatus,
    LowTreatmentReason? reason,
    String? deviceStatusHash,
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
      suggestionAt: activeSuggestion == null ? null : clock.now(),
      deviceStatusDate: activeSuggestion?.date,
      reason: activeSuggestion == null
          ? null
          : reason ?? LowTreatmentReason.carbsReq,
      deviceStatusHash: activeSuggestion == null ? null : deviceStatusHash,
    );
  }

  Future<LowTreatmentContext?> save(LowTreatmentContextDraft draft) async {
    state = const AsyncLoading();

    try {
      final mealId = await draft.map(
        draft: (draft) async {
          final meal = await _addMealUseCase.call(
            _lowTreatmentMealDraft(draft.meal),
          );
          return meal.id;
        },
        existing: (existing) async => existing.mealId,
      );

      final context = await _addContextUseCase.call(draft, mealId: mealId);
      state = AsyncData(context);
      return context;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
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
}

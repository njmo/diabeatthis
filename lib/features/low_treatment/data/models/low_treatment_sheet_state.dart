import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../drafts/low_treatment_context_draft.dart';
import 'low_treatment_related_record.dart';

class LowTreatmentSheetState {
  const LowTreatmentSheetState({
    required this.contextDraft,
    this.relatedMeal,
    this.relatedActivityLog,
    this.relatedAutoAttachEnabled = true,
    this.isSaving = false,
  });

  final LowTreatmentContextDraft contextDraft;
  final Meal? relatedMeal;
  final ActivityLogSummaryData? relatedActivityLog;
  final bool relatedAutoAttachEnabled;
  final bool isSaving;

  LowTreatmentRelatedRecord? get selectedRelatedRecord {
    if (contextDraft.relatedMealId != null &&
        relatedMeal?.id == contextDraft.relatedMealId) {
      return relatedMealRecord;
    }

    if (contextDraft.relatedActivityLogId != null &&
        relatedActivityLog?.id == contextDraft.relatedActivityLogId) {
      return relatedActivityRecord;
    }

    return null;
  }

  LowTreatmentRelatedRecord? get relatedMealRecord {
    final meal = relatedMeal;
    if (meal == null) {
      return null;
    }

    return LowTreatmentRelatedRecord.meal(id: meal.id, name: meal.name);
  }

  LowTreatmentRelatedRecord? get relatedActivityRecord {
    final activityLog = relatedActivityLog;
    if (activityLog == null) {
      return null;
    }

    return LowTreatmentRelatedRecord.activity(
      id: activityLog.id,
      name: activityLog.activityName,
    );
  }

  bool get canSwitchToRelatedMeal {
    return relatedMealRecord != null &&
        selectedRelatedRecord is! LowTreatmentRelatedMealRecord;
  }

  bool get canSwitchToRelatedActivity {
    return relatedActivityRecord != null &&
        selectedRelatedRecord is! LowTreatmentRelatedActivityRecord;
  }

  double get suggestedCarbs {
    return contextDraft.suggestedCarbs ?? 0;
  }

  int get suggestedWithinMinutes {
    return contextDraft.suggestedWithinMinutes ?? 0;
  }

  LowTreatmentReason get reason => contextDraft.reason;

  bool get hasAapsSuggestion => suggestedCarbs > 0;

  bool get canSave => mealIngredients.isNotEmpty && !isSaving;

  List<MealIngredientsDraft> get mealIngredients =>
      contextDraft.meal.mealIngredients;

  LowTreatmentSheetState copyWith({
    LowTreatmentContextDraft? contextDraft,
    Meal? relatedMeal,
    ActivityLogSummaryData? relatedActivityLog,
    bool clearRelatedMeal = false,
    bool clearRelatedActivityLog = false,
    bool? relatedAutoAttachEnabled,
    bool? isSaving,
  }) {
    return LowTreatmentSheetState(
      contextDraft: contextDraft ?? this.contextDraft,
      relatedMeal: clearRelatedMeal ? null : relatedMeal ?? this.relatedMeal,
      relatedActivityLog: clearRelatedActivityLog
          ? null
          : relatedActivityLog ?? this.relatedActivityLog,
      relatedAutoAttachEnabled:
          relatedAutoAttachEnabled ?? this.relatedAutoAttachEnabled,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

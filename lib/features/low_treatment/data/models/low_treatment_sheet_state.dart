import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../drafts/low_treatment_context_draft.dart';

class LowTreatmentSheetState {
  const LowTreatmentSheetState({
    required this.contextDraft,
    this.relatedMeal,
    this.relatedMealAutoAttachEnabled = true,
    this.isSaving = false,
  });

  final LowTreatmentContextDraft contextDraft;
  final Meal? relatedMeal;
  final bool relatedMealAutoAttachEnabled;
  final bool isSaving;

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
    bool clearRelatedMeal = false,
    bool? relatedMealAutoAttachEnabled,
    bool? isSaving,
  }) {
    return LowTreatmentSheetState(
      contextDraft: contextDraft ?? this.contextDraft,
      relatedMeal: clearRelatedMeal ? null : relatedMeal ?? this.relatedMeal,
      relatedMealAutoAttachEnabled:
          relatedMealAutoAttachEnabled ?? this.relatedMealAutoAttachEnabled,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../drafts/low_treatment_context_draft.dart';

class LowTreatmentSheetState {
  const LowTreatmentSheetState({
    required this.contextDraft,
    this.isSaving = false,
  });

  final LowTreatmentContextDraft contextDraft;
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
    bool? isSaving,
  }) {
    return LowTreatmentSheetState(
      contextDraft: contextDraft ?? this.contextDraft,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

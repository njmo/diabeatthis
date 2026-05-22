import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../drafts/low_treatment_context_draft.dart';

class LowTreatmentSheetState {
  const LowTreatmentSheetState({required this.contextDraft});

  final LowTreatmentContextDraft contextDraft;

  double get suggestedCarbs {
    return contextDraft.suggestedCarbs ?? 0;
  }

  int get suggestedWithinMinutes {
    return contextDraft.suggestedWithinMinutes ?? 0;
  }

  LowTreatmentReason get reason => contextDraft.reason;

  bool get hasAapsSuggestion => suggestedCarbs > 0;

  List<MealIngredientsDraft> get mealIngredients {
    return contextDraft.map(
      draft: (draft) => draft.meal.mealIngredients,
      existing: (_) {
        throw StateError(
          'Low treatment sheet does not support existing context editing yet.',
        );
      },
    );
  }

  LowTreatmentSheetState copyWith({LowTreatmentContextDraft? contextDraft}) {
    return LowTreatmentSheetState(
      contextDraft: contextDraft ?? this.contextDraft,
    );
  }
}

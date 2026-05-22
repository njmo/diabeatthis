import 'package:drift/drift.dart' as d;

import '../../../../core/domain/model/low_treatment_context.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../drafts/low_treatment_context_draft.dart';

extension LowTreatmentContextToDraft on domain.LowTreatmentContext {
  LowTreatmentContextDraft toDraft({required MealDraft meal}) {
    return LowTreatmentContextDraft(
      mealId: mealId,
      meal: meal,
      relatedMealId: relatedMealId,
      source: source,
      suggestedCarbs: suggestedCarbs,
      suggestedWithinMinutes: suggestedWithinMinutes,
      suggestionAt: suggestionAt,
      deviceStatusDate: deviceStatusDate,
      reason: reason,
    );
  }
}

extension LowTreatmentContextDraftToCompanion on LowTreatmentContextDraft {
  LowTreatmentContextCompanion toCompanion() {
    final persistedMealId = mealId;
    if (persistedMealId == null) {
      throw StateError('Low treatment context draft requires mealId.');
    }

    return LowTreatmentContextCompanion.insert(
      mealId: d.Value(persistedMealId),
      relatedMealId: d.Value(relatedMealId),
      source: source.storageValue,
      suggestedCarbs: d.Value(suggestedCarbs),
      suggestedWithinMinutes: d.Value(suggestedWithinMinutes),
      suggestionAt: d.Value(suggestionAt?.millisecondsSinceEpoch),
      deviceStatusDate: d.Value(deviceStatusDate?.millisecondsSinceEpoch),
      reason: d.Value(reason.storageValue),
    );
  }
}

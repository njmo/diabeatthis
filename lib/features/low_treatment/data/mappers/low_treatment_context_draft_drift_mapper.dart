import 'package:drift/drift.dart' as d;

import '../../../../core/domain/model/low_treatment_context.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../drafts/low_treatment_context_draft.dart';

extension LowTreatmentContextToDraft on domain.LowTreatmentContext {
  LowTreatmentContextDraft toDraft() {
    return LowTreatmentContextDraft.existing(
      mealId: mealId,
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
  LowTreatmentContextCompanion toCompanion({int? mealId}) {
    return map(
      draft: (draft) => _toCompanion(
        mealId: mealId,
        relatedMealId: draft.relatedMealId,
        source: draft.source,
        suggestedCarbs: draft.suggestedCarbs,
        suggestedWithinMinutes: draft.suggestedWithinMinutes,
        suggestionAt: draft.suggestionAt,
        deviceStatusDate: draft.deviceStatusDate,
        reason: draft.reason,
      ),
      existing: (existing) => _toCompanion(
        mealId: mealId ?? existing.mealId,
        relatedMealId: existing.relatedMealId,
        source: existing.source,
        suggestedCarbs: existing.suggestedCarbs,
        suggestedWithinMinutes: existing.suggestedWithinMinutes,
        suggestionAt: existing.suggestionAt,
        deviceStatusDate: existing.deviceStatusDate,
        reason: existing.reason,
      ),
    );
  }

  LowTreatmentContextCompanion _toCompanion({
    required int? mealId,
    required int? relatedMealId,
    required domain.LowTreatmentContextSource source,
    required double? suggestedCarbs,
    required int? suggestedWithinMinutes,
    required DateTime? suggestionAt,
    required DateTime? deviceStatusDate,
    required domain.LowTreatmentReason reason,
  }) {
    if (mealId == null) {
      throw StateError('Low treatment context draft requires mealId.');
    }

    return LowTreatmentContextCompanion.insert(
      mealId: d.Value(mealId),
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

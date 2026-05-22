import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../meals/data/drafts/meal_draft.dart';

part 'low_treatment_context_draft.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class LowTreatmentContextDraft with _$LowTreatmentContextDraft {
  const factory LowTreatmentContextDraft.draft({
    required MealDraft meal,
    int? relatedMealId,
    required LowTreatmentContextSource source,
    double? suggestedCarbs,
    int? suggestedWithinMinutes,
    DateTime? suggestionAt,
    DateTime? deviceStatusDate,
    required LowTreatmentReason reason,
  }) = _LowTreatmentContextDraftNew;

  const factory LowTreatmentContextDraft.existing({
    required int mealId,
    int? relatedMealId,
    required LowTreatmentContextSource source,
    double? suggestedCarbs,
    int? suggestedWithinMinutes,
    DateTime? suggestionAt,
    DateTime? deviceStatusDate,
    required LowTreatmentReason reason,
  }) = _LowTreatmentContextDraftExisting;
}

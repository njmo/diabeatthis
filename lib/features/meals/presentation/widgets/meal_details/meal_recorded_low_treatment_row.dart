import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../core/domain/model/low_treatment_context.dart';
import '../../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../../../low_treatment/presentation/formatters/low_treatment_context_formatters.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealRecordedLowTreatmentRow extends StatelessWidget {
  final RecordedLowTreatment entry;
  final DateTime reference;
  const MealRecordedLowTreatmentRow({
    super.key,
    required this.entry,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final reason = switch (entry.reason) {
      null => context.lang.uiUnknownReason,
      LowTreatmentReason.plannedActivity => context.lang.uiPlannedActivity,
      LowTreatmentReason.unplannedActivity => context.lang.uiUnplannedActivity,
      LowTreatmentReason.symptoms => context.lang.lowReasonSymptomsLabel,
      final reason => lowTreatmentReasonLabel(reason, context.lang),
    };
    return MealInfoRow(
      label: context.lang.mealLowRelativeTime(
        mealDateTime(entry.eatenAt.toLocal()),
        formatDurationOffset(entry.eatenAt.difference(reference)),
      ),
      value: [
        entry.netCarbsGrams == null
            ? context.lang.uiConsumedAmountUnknown
            : context.lang.mealLowRecordedAmount(
                formatGrams(entry.netCarbsGrams!),
              ),
        reason,
        if (entry.suggestedCarbs != null)
          context.lang.mealLowAapsSuggestion(
            formatGrams(entry.suggestedCarbs!),
          ),
        if (entry.relatedMealId != null) context.lang.uiLinkedToAMeal2,
        if (entry.relatedActivityLogId != null)
          context.lang.uiLinkedToAnActivity,
      ].join(' · '),
    );
  }
}

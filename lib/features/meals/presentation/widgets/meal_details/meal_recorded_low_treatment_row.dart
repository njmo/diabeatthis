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
      null => 'Powód nieznany',
      LowTreatmentReason.plannedActivity => 'Planowana aktywność',
      LowTreatmentReason.unplannedActivity => 'Nieplanowana aktywność',
      LowTreatmentReason.symptoms => 'Objawy',
      final reason => lowTreatmentReasonLabel(reason, context.lang),
    };
    return MealInfoRow(
      label:
          '${mealDateTime(entry.eatenAt.toLocal())} · ${formatDurationOffset(entry.eatenAt.difference(reference))} względem porady',
      value: [
        entry.netCarbsGrams == null
            ? 'Ilość spożyta nieznana'
            : 'Zapisane spożycie: ${formatGrams(entry.netCarbsGrams!)} netto',
        reason,
        if (entry.suggestedCarbs != null)
          'Propozycja AAPS: ${formatGrams(entry.suggestedCarbs!)}',
        if (entry.relatedMealId != null) 'Powiązano z posiłkiem',
        if (entry.relatedActivityLogId != null) 'Powiązano z aktywnością',
      ].join(' · '),
    );
  }
}

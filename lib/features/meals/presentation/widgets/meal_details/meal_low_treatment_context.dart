import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_recorded_low_treatment_row.dart';

class MealLowTreatmentContext extends StatelessWidget {
  final DateTime adviceAt;
  final MealAnalysisData? analysis;
  const MealLowTreatmentContext({
    super.key,
    required this.adviceAt,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final history = analysis;
    if (history == null) {
      return Text(context.lang.uiLowTreatmentHistoryIsNotAvailableYet);
    }
    final entries = history.lowTreatments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.lang.uiAllLowTreatmentsInTheAnalysisWindow),
        MealInfoRow(
          label: context.lang.uiRecordWindow,
          value:
              '${mealDateTime(history.eventStart.toLocal())} – ${mealDateTime(history.eventEnd.toLocal())}',
        ),
        if (entries.isEmpty)
          Text(context.lang.uiNoRecordedLowTreatmentsInThisWindow),
        for (final entry in entries)
          MealRecordedLowTreatmentRow(entry: entry, reference: adviceAt),
        Text(context.lang.mealReconstructedContextNote),
        Text(context.lang.uiAnEventInThisWindowIsNotNecessarilyRelated),
      ],
    );
  }
}

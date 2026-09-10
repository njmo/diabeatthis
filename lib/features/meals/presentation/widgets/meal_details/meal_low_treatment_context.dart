import 'package:flutter/material.dart';

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
      return const Text('Historia dosłodzeń nie jest jeszcze dostępna.');
    }
    final entries = history.lowTreatments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Wszystkie dosłodzenia w oknie analizy'),
        MealInfoRow(
          label: 'Okno zapisów',
          value:
              '${mealDateTime(history.eventStart.toLocal())} – ${mealDateTime(history.eventEnd.toLocal())}',
        ),
        if (entries.isEmpty)
          const Text('Brak zapisanych dosłodzeń w tym oknie.'),
        for (final entry in entries)
          MealRecordedLowTreatmentRow(entry: entry, reference: adviceAt),
        const Text(
          'Kontekst odtworzony podczas analizy, nie zapis danych użytych przez Advisor. Historia może zawierać późniejsze uzupełnienia i zmiany.',
        ),
        const Text(
          'Obecność zdarzenia w tym oknie nie oznacza, że dotyczy tego posiłku ani że wynika z porady.',
        ),
      ],
    );
  }
}

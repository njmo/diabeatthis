import 'package:flutter/material.dart';

import '../../../../../common/meal/stored_meal_decision.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../data/models/meal_advice_history_comparison.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_low_treatment_context.dart';
import 'meal_wizard_history_row.dart';

class MealAdviceHistorySection extends StatelessWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  const MealAdviceHistorySection({
    super.key,
    required this.details,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final history = analysis;
    final decision = details.advisorDecision;
    final label = storedMealDecisionLabel(decision?.result);
    final eating = details.recordedEatingStartedAt;
    final comparison = history == null
        ? null
        : MealAdviceHistoryComparison(history);
    final stats = history?.glucoseStats;
    return MealSectionTile(
      title: 'Porada a zapisane zdarzenia',
      children: [
        MealInfoRow(
          label: decision?.isManual == true
              ? 'Decyzja manualna'
              : 'Zapisana porada',
          value: decision == null
              ? 'Brak zapisu'
              : '$label · ${mealDateTime(decision.createdAt.toLocal())}',
        ),
        if (decision != null && !decision.isManual)
          MealInfoRow(
            label: 'Proponowane oczekiwanie',
            value: '${decision.initialWaitTime} min',
          ),
        MealInfoRow(
          label: 'Zarejestrowany początek jedzenia',
          value: eating == null ? 'Nieznany' : mealDateTime(eating.toLocal()),
        ),
        const Text(
          'Początek jedzenia pochodzi ze statusu posiłku. Czas wpisania węglowodanów nie zastępuje tej informacji.',
        ),
        if (decision != null)
          MealLowTreatmentContext(
            adviceAt: decision.createdAt,
            analysis: history,
          ),
        if (history == null)
          const Text('Historia nie jest jeszcze dostępna.')
        else ...[
          MealInfoRow(
            label: 'Okno zdarzeń',
            value:
                '${mealDateTime(history.eventStart.toLocal())} – ${mealDateTime(history.eventEnd.toLocal())}',
          ),
          if (comparison!.wizards.isEmpty)
            const Text('Brak wpisu Bolus Wizarda w pobranym oknie.'),
          for (final wizard in comparison.wizards)
            MealWizardHistoryRow(wizard: wizard),
          const Text(
            'Wynik kalkulatora nie potwierdza podania insuliny. Procent Wizarda nie dowodzi zastosowania się do porady.',
          ),
          if (comparison.deliveries.isEmpty)
            const Text('Brak zapisanego bolusa manualnego w pobranym oknie.'),
          for (final bolus in comparison.deliveries)
            MealInfoRow(
              label: 'Zapis podania ${mealDateTime(bolus.createdAt.toLocal())}',
              value:
                  '${formatUnits(bolus.insulin)}${eating == null ? '' : ' · ${formatDurationOffset(bolus.createdAt.difference(eating))} względem początku jedzenia'}',
            ),
          MealInfoRow(
            label: 'Pozostałe podania / korekty w oknie',
            value:
                '${comparison.insulin.otherCount} · ${formatUnits(comparison.insulin.otherUnits)}',
          ),
          const Text(
            'Zdarzenia w tym oknie nie są automatycznie przypisane do posiłku. Brak wpisu nie dowodzi braku podania.',
          ),
          MealInfoRow(
            label: 'Obserwacja CGM',
            value:
                '${mealDateTime(history.mealTime.toLocal())} – ${mealDateTime(history.chartEnd.toLocal())}',
          ),
          if (eating == null)
            const Text(
              'Okno CGM korzysta z czasu zastępczego analizy; rzeczywisty początek jedzenia jest nieznany.',
            ),
          MealInfoRow(
            label: 'Minimum / maksimum CGM',
            value:
                '${formatMgdl(stats?.minGlucose)} / ${formatMgdl(stats?.maxGlucose)}',
          ),
          if (!history.hasFullGlucoseWindow)
            Text(
              'Obserwacja jeszcze trwa. Docelowe okno: ${formatDurationLabel(history.postMealWindow)}.',
            ),
          if (history.needsHistoryDownload)
            const Text(
              'Pokrycie historii CGM jest niepełne; statystyki opisują tylko dostępne odczyty.',
            ),
          MealInfoRow(
            label: 'Aktywności w kontekście analizy',
            value: history.linkedActivities.isEmpty
                ? 'Brak zapisanych aktywności'
                : history.linkedActivities
                      .map(
                        (a) =>
                            '${a.activityName} (${mealDateTime(a.startedAt.toLocal())})',
                      )
                      .join(', '),
          ),
          MealInfoRow(
            label: 'Inne posiłki w kontekście',
            value: '${history.linkedMeals.length}',
          ),
          const Text(
            'Przebieg CGM obejmuje również wpływ kolejnych podań, posiłków i aktywności. Nie rozstrzyga skuteczności samej porady.',
          ),
        ],
      ],
    );
  }
}

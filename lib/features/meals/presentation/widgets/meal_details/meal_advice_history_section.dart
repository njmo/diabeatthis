import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
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
      title: context.lang.uiAdviceAndRecordedEvents,
      children: [
        MealInfoRow(
          label: decision?.isManual == true
              ? context.lang.mealManualDecisionLabel
              : context.lang.mealRecordedAdvice,
          value: decision == null
              ? context.lang.mealNoRecord
              : '$label · ${mealDateTime(decision.createdAt.toLocal())}',
        ),
        if (decision != null && !decision.isManual)
          MealInfoRow(
            label: context.lang.uiSuggestedWait,
            value: '${decision.initialWaitTime} min',
          ),
        MealInfoRow(
          label: context.lang.uiRecordedEatingStart,
          value: eating == null
              ? context.lang.mealUnknown
              : mealDateTime(eating.toLocal()),
        ),
        Text(context.lang.mealEatingStartSourceNote),
        if (decision != null)
          MealLowTreatmentContext(
            adviceAt: decision.createdAt,
            analysis: history,
          ),
        if (history == null)
          Text(context.lang.uiHistoryIsNotAvailableYet)
        else ...[
          MealInfoRow(
            label: context.lang.uiEventWindow,
            value:
                '${mealDateTime(history.eventStart.toLocal())} – ${mealDateTime(history.eventEnd.toLocal())}',
          ),
          if (comparison!.wizards.isEmpty)
            Text(context.lang.uiNoBolusWizardEntryInTheLoadedWindow),
          for (final wizard in comparison.wizards)
            MealWizardHistoryRow(wizard: wizard),
          Text(context.lang.mealWizardDeliveryLimitNote),
          if (comparison.deliveries.isEmpty)
            Text(context.lang.uiNoRecordedManualBolusInTheLoadedWindow),
          for (final bolus in comparison.deliveries)
            MealInfoRow(
              label: context.lang.mealDoseRecordedAt(
                mealDateTime(bolus.createdAt.toLocal()),
              ),
              value:
                  '${formatUnits(bolus.insulin)}${eating == null ? '' : context.lang.mealDoseRelativeTime(formatDurationOffset(bolus.createdAt.difference(eating)))}',
            ),
          MealInfoRow(
            label: context.lang.uiOtherDosesCorrectionsInTheWindow,
            value:
                '${comparison.insulin.otherCount} · ${formatUnits(comparison.insulin.otherUnits)}',
          ),
          Text(context.lang.mealEventAttributionNote),
          MealInfoRow(
            label: context.lang.uiCGMObservation,
            value:
                '${mealDateTime(history.mealTime.toLocal())} – ${mealDateTime(history.chartEnd.toLocal())}',
          ),
          if (eating == null)
            Text(context.lang.uiTheCGMWindowUsesAFallbackAnalysisTimeThe),
          MealInfoRow(
            label: context.lang.uiMinimumMaximumCGM,
            value:
                '${formatMgdl(stats?.minGlucose)} / ${formatMgdl(stats?.maxGlucose)}',
          ),
          if (!history.hasFullGlucoseWindow)
            Text(
              'Obserwacja jeszcze trwa. Docelowe okno: ${formatDurationLabel(history.postMealWindow)}.',
            ),
          if (history.needsHistoryDownload)
            Text(context.lang.mealPartialCgmStatisticsNote),
          MealInfoRow(
            label: context.lang.uiActivitiesInTheAnalysisContext,
            value: history.linkedActivities.isEmpty
                ? context.lang.uiNoRecordedActivities
                : history.linkedActivities
                      .map(
                        (a) =>
                            '${a.activityName} (${mealDateTime(a.startedAt.toLocal())})',
                      )
                      .join(', '),
          ),
          MealInfoRow(
            label: context.lang.uiOtherMealsInContext,
            value: '${history.linkedMeals.length}',
          ),
          Text(context.lang.uiTheCGMCourseAlsoIncludesTheEffectsOfSubsequent),
        ],
      ],
    );
  }
}

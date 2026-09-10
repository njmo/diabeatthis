import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../domain/models/meal_outcome_context.dart';

class MealOutcomeFacts extends StatelessWidget {
  final MealOutcomeContext data;
  const MealOutcomeFacts({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String time(DateTime at) =>
        DateFormat('HH:mm', lang.localeName).format(at.toLocal());
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(lang.mealOutcomeFactsTitle),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${time(data.mealTime)}–${time(data.observedUntil)} · ${data.isTimeWindowComplete ? lang.mealOutcomeWindowComplete : lang.mealOutcomeWindowPartial}',
            ),
            const SizedBox(height: 12),
            ResponsiveMetricList(
              minimumWidth: 100,
              maxColumns: 3,
              children: [
                AnalysisMetric(
                  label: lang.dayRecordedBoluses,
                  value: '${number.format(data.boluses.units)} U',
                ),
                AnalysisMetric(
                  label: lang.dayBasalTitle,
                  value: data.basal.coveredDuration == Duration.zero
                      ? '—'
                      : '${number.format(data.basal.units)} U',
                  detail:
                      '${lang.dayBasalCoverage}: ${number.format(data.basal.coverage * 100)}%',
                ),
                AnalysisMetric(
                  label: lang.beforeMealLows,
                  value: '${data.lowTreatments.length}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lang.mealOutcomeEarlierEcarbs,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(lang.beforeMealScheduleOnly),
            if (!data.extendedCarbs.any((e) => e.startedBeforeMeal))
              Text(lang.beforeMealNoEvents),
            for (final overlap in data.extendedCarbs.where(
              (e) => e.startedBeforeMeal,
            ))
              Text(
                '${time(overlap.overlapStart)}–${time(overlap.overlapEnd)} · ${number.format(overlap.scheduledGrams)} g',
              ),
            const SizedBox(height: 12),
            Text('${lang.mealOutcomeActivities}: ${data.activities.length}'),
            Text(
              '${lang.mealOutcomeSubsequentMeals}: ${data.subsequentMeals?.length.toString() ?? lang.beforeMealUnavailable}',
            ),
            Text(
              lang.beforeMealReconstruction,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

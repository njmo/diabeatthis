import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../domain/models/before_meal_context.dart';
import 'before_meal_history_facts.dart';

class BeforeMealFacts extends StatelessWidget {
  final BeforeMealContext data;
  final bool hasRecordedStart;
  const BeforeMealFacts({
    super.key,
    required this.data,
    required this.hasRecordedStart,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String value(num? n, String unit) =>
        n == null ? '—' : '${number.format(n)} $unit';
    String time(DateTime at) =>
        DateFormat('d.MM HH:mm', lang.localeName).format(at.toLocal());
    final status = data.latestDeviceStatus;
    final basal = data.basal;
    final hasBasal = basal != null && basal.coveredDuration > Duration.zero;
    String source(BeforeMealSource source) => switch (source) {
      BeforeMealSource.glucose => lang.mealReviewGlucose,
      BeforeMealSource.deviceStatus => 'AAPS',
      BeforeMealSource.treatments => lang.dayInsulinTitle,
      BeforeMealSource.meals => lang.beforeMealPreviousMeals,
      BeforeMealSource.lowTreatments => lang.beforeMealLows,
      BeforeMealSource.activities => lang.beforeMealActivities,
      BeforeMealSource.podAge => lang.beforeMealPod,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${hasRecordedStart ? lang.mealReviewRecordedStart : lang.mealReviewFallbackStart}: ${time(data.asOf)}',
        ),
        if (!hasRecordedStart) Text(lang.mealReviewFallbackContext),
        if (data.failedSources.isNotEmpty)
          Text(
            '${lang.beforeMealUnavailable}: ${data.failedSources.map(source).join(', ')}',
          ),
        const SizedBox(height: 12),
        ResponsiveMetricList(
          maxColumns: 3,
          minimumWidth: 110,
          children: [
            AnalysisMetric(
              label: lang.mealReviewGlucose,
              value: value(data.latestCgm?.sgv, 'mg/dl'),
              detail: data.latestCgm == null
                  ? lang.mealReviewNoNearbyReading
                  : '${time(data.latestCgm!.date)} · ${data.hasFreshCgm ? lang.beforeMealFresh : lang.beforeMealStale}',
            ),
            AnalysisMetric(
              label: 'IOB',
              value: value(status?.hasIob == true ? status!.iob : null, 'U'),
              detail: status == null
                  ? lang.mealReviewNoNearbyReading
                  : time(status.date),
            ),
            AnalysisMetric(
              label: 'COB',
              value: value(status?.hasCob == true ? status!.cob : null, 'g'),
            ),
            AnalysisMetric(
              label: lang.dayRecordedBoluses,
              value: value(data.boluses?.units, 'U'),
              detail:
                  '${time(data.asOf.subtract(data.windows.insulin))}–${time(data.asOf)}',
            ),
            AnalysisMetric(
              label: lang.dayBasalTitle,
              value: value(hasBasal ? basal.units : null, 'U'),
              detail:
                  '${lang.dayBasalCoverage}: ${value(basal == null ? null : basal.coverage * 100, '%')}',
            ),
            AnalysisMetric(
              label: lang.beforeMealPod,
              value: data.podAge == null
                  ? '—'
                  : '${data.podAge!.inDays} d ${data.podAge!.inHours.remainder(24)} h',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          lang.beforeMealReconstruction,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        BeforeMealHistoryFacts(data: data),
      ],
    );
  }
}

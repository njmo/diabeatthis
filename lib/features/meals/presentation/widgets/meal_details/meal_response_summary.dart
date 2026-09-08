import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_rise_summary.dart';
import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import 'meal_detail_formatters.dart';

class MealResponseSummary extends StatelessWidget {
  final GlucoseWindowSummary summary;
  final bool complete;

  const MealResponseSummary({
    super.key,
    required this.summary,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    final peak = summary.peak;
    final rise = GlucoseRiseSummary.fromReadings(summary.readings);
    final riseStart = rise.startedAt;
    final delta = summary.endDelta;
    String after(DateTime time) => messages.mealResponseAfter(
      formatDurationLabel(time.difference(summary.start)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveMetricList(
          maxColumns: 2,
          children: [
            AnalysisMetric(
              icon: Icons.schedule,
              label: messages.mealResponsePeakTime,
              value: peak == null ? '—' : after(peak.date),
              detail: peak == null
                  ? messages.mealResponseMissing
                  : '${peak.sgv} mg/dl · ${mealTime(peak.date)}',
            ),
            AnalysisMetric(
              icon: Icons.trending_up,
              label: messages.mealResponseRiseTime,
              value: riseStart == null ? '—' : after(riseStart),
              detail: riseStart != null
                  ? mealTime(riseStart)
                  : rise.hasObservation
                  ? messages.mealResponseNoRise
                  : messages.mealResponseMissing,
            ),
            AnalysisMetric(
              icon: Icons.compare_arrows,
              label: complete
                  ? messages.mealResponseDelta
                  : messages.mealResponseDeltaSoFar,
              value: delta == null
                  ? '—'
                  : '${delta > 0 ? '+' : ''}$delta mg/dl',
              detail: delta == null
                  ? messages.mealResponseMissingEndpoints
                  : messages.mealResponseDeltaValues(
                      summary.baseline!.sgv,
                      summary.endpoint!.sgv,
                      mealTime(summary.endpoint!.date),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          complete
              ? messages.mealResponseObserved
              : messages.mealResponseOngoing,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            messages.mealResponseMethodTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                messages.mealResponseRiseMethod,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

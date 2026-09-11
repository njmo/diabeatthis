import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/history/glucose_window_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';

/// The latest actual sample is not necessarily an observation of the window end.
class GlucoseBoundaryMetrics extends StatelessWidget {
  final GlucoseWindowSummary summary;
  final String startLabel;
  const GlucoseBoundaryMetrics({
    super.key,
    required this.summary,
    required this.startLabel,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final first = summary.baseline;
    final last = summary.last;
    String time(DateTime at) =>
        DateFormat('HH:mm', lang.localeName).format(at.toLocal());
    return ResponsiveMetricList(
      maxColumns: 2,
      minimumWidth: 110,
      children: [
        AnalysisMetric(
          label: startLabel,
          value: first == null ? '—' : '${first.sgv} mg/dl',
          detail: first == null
              ? lang.mealReviewNoNearbyReading
              : time(first.date),
        ),
        AnalysisMetric(
          label: lang.mealReviewLast,
          value: last == null ? '—' : '${last.sgv} mg/dl',
          detail: last == null ? lang.beforeMealUnavailable : time(last.date),
        ),
      ],
    );
  }
}

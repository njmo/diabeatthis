import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../core/domain/model/glucose.dart';
import '../utils/activity_log_formatters.dart';

class ActivitySessionChart extends StatelessWidget {
  final String title;
  final DateTime start;
  final DateTime end;
  final List<Glucose> readings;
  final DateTime? activityEnd;
  const ActivitySessionChart({
    super.key,
    required this.title,
    required this.start,
    required this.end,
    required this.readings,
    this.activityEnd,
  });
  @override
  Widget build(BuildContext context) => SummaryDetailCard(
    title: title,
    icon: Icons.show_chart_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimelineAnalysisCharts(
          chartStart: start,
          chartEnd: end,
          glucoseReadings: readings,
          deviceStatuses: const [],
          fitToWidth: true,
          showDeviceMetrics: false,
          overviewStyle: true,
          ranges: [
            if (activityEnd != null)
              TimelineChartRange(
                start: activityEnd!,
                end: end,
                color: Theme.of(context).colorScheme.tertiary,
                alpha: 0.10,
                label: context.lang.activityPostEndChartArea,
                startLabel: context.lang.activityEndLabel,
                startIcon: Icons.stop_rounded,
                endIcon: Icons.bloodtype_rounded,
                endLabel: context.lang.activityPostEndChartArea,
              ),
          ],
        ),
        if (activityEnd != null) ...[
          const SizedBox(height: 12),
          Text(
            context.lang.activityExtendedChartExplanation(
              formatActivityLogTime(activityEnd!),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

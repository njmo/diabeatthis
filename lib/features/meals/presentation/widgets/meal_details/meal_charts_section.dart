import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../../common/widgets/timeline_selection_summary.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import '../../controllers/meal_details_controller.dart';
import '../meal_analysis_charts.dart';
import 'meal_corrections_summary.dart';
import 'meal_detail_formatters.dart';
import 'meal_eating_period_legend.dart';

class MealChartsSection extends HookConsumerWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;
  final bool advanced;

  const MealChartsSection({
    super.key,
    required this.details,
    required this.analysis,
    required this.analysisError,
    required this.selectedTimestamp,
    this.advanced = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoomed = useState(false);
    final data = analysis;
    final messages = context.lang;
    if (data == null) {
      return DetailSectionCard(
        title: messages.mealReviewTimeline,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(analysisError ?? messages.mealNoAnalysisData),
          ),
        ],
      );
    }
    final selected = selectedTimestamp ?? data.mealTime;
    void select(DateTime time) => ref
        .read(mealDetailsControllerProvider(details.meal.id).notifier)
        .selectTimestamp(time);
    return DetailSectionCard(
      title: messages.mealReviewTimeline,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mealTime(data.chartStart)}–${mealTime(data.chartEnd)} · mg/dl',
              ),
              const SizedBox(height: 16),
              MealCorrectionsSummary(analysis: data),
              const SizedBox(height: 12),
              if (advanced)
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(messages.mealReviewOverview),
                      selected: !zoomed.value,
                      onSelected: (_) => zoomed.value = false,
                    ),
                    ChoiceChip(
                      label: Text(messages.mealReviewZoom),
                      selected: zoomed.value,
                      onSelected: (_) => zoomed.value = true,
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TimelineAnalysisCharts(
                chartStart: data.chartStart,
                chartEnd: data.chartEnd,
                focusTimestamp: selected,
                selectedTimestamp: advanced ? selectedTimestamp : null,
                fitToWidth: !advanced || !zoomed.value,
                showDeviceMetrics: false,
                glucoseReadings: data.glucoseReadings,
                deviceStatuses: data.deviceStatuses,
                events:
                    mealTimelineChartEvents(data, correctionsOnly: !advanced)
                        .where(
                          (event) =>
                              !event.timestamp.isBefore(data.chartStart) &&
                              !event.timestamp.isAfter(data.chartEnd),
                        )
                        .toList(),
                ranges: mealTimelineChartRanges(
                  data,
                  details: details,
                  messages: messages,
                  eatingColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTimestampSelected: advanced ? select : null,
              ),
              const SizedBox(height: 8),
              MealEatingPeriodLegend(details: details),
              const SizedBox(height: 8),
              Text(
                messages.mealReviewRangeLegend,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (advanced && selectedTimestamp == null)
                Text(
                  messages.mealReviewTouchChart,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (advanced && selectedTimestamp != null) ...[
                if (selected.isBefore(data.chartStart) ||
                    selected.isAfter(data.chartEnd))
                  Text(messages.mealReviewOutsideWindow),
                TimelineSelectionSummary(
                  timestamp: selected,
                  glucoseReadings: data.glucoseReadings,
                  deviceStatuses: data.deviceStatuses,
                ),
              ],
              if (advanced && data.deviceStatuses.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(messages.mealReviewDeviceData),
                  children: [
                    for (final metric in TimelineDeviceMetric.values) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          metric == TimelineDeviceMetric.cob
                              ? messages.mealReviewCob
                              : messages.mealReviewIob,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TimelineDeviceMetricChart(
                        chartStart: data.chartStart,
                        chartEnd: data.chartEnd,
                        selectedTimestamp: selected,
                        deviceStatuses: data.deviceStatuses,
                        metric: metric,
                        onTimestampSelected: select,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

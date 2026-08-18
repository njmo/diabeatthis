import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import '../../controllers/meal_details_controller.dart';
import '../meal_analysis_charts.dart';
import 'meal_detail_components.dart';

class MealChartsSection extends ConsumerWidget {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;

  const MealChartsSection({
    super.key,
    required this.details,
    required this.analysis,
    required this.analysisError,
    required this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = this.analysis;

    if (analysis == null) {
      return MealSectionTile(
        title: context.lang.mealGlucoseAnalysisTitle,
        children: [
          MealInfoRow(
            label: 'Nightscout',
            value: analysisError ?? context.lang.mealNoAnalysisData,
          ),
        ],
      );
    }

    return MealSectionTile(
      title: context.lang.mealGlucoseCobIobTitle,
      initiallyExpanded: true,
      children: [
        TimelineAnalysisCharts(
          chartStart: analysis.chartStart,
          chartEnd: analysis.chartEnd,
          focusTimestamp: analysis.mealTime,
          selectedTimestamp: selectedTimestamp,
          glucoseReadings: analysis.glucoseReadings,
          deviceStatuses: analysis.deviceStatuses,
          events: mealTimelineChartEvents(analysis),
          ranges: mealTimelineChartRanges(analysis),
          onTimestampSelected: (timestamp) {
            ref
                .read(mealDetailsControllerProvider(details.meal.id).notifier)
                .selectTimestamp(timestamp);
          },
        ),
      ],
    );
  }
}

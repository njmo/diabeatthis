import 'package:flutter/material.dart';

import '../../../../common/history/treatment_presentation.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/stress_event_chart_ranges.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../data/models/activity_log_analysis_data.dart';

class ActivityAnalysisCharts extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  final DateTime? selectedTimestamp;
  final ValueChanged<DateTime>? onTimestampSelected;

  const ActivityAnalysisCharts({
    super.key,
    required this.analysis,
    this.selectedTimestamp,
    this.onTimestampSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TimelineAnalysisCharts(
      chartStart: analysis.chartStart,
      chartEnd: analysis.chartEnd,
      focusTimestamp: analysis.activityStart,
      selectedTimestamp: selectedTimestamp,
      glucoseReadings: analysis.glucoseReadings,
      deviceStatuses: analysis.deviceStatuses,
      events: _activityEvents(context, analysis),
      ranges: _activityRanges(context, analysis),
      onTimestampSelected: onTimestampSelected,
    );
  }
}

List<TimelineChartRange> _activityRanges(
  BuildContext context,
  ActivityLogAnalysisData analysis,
) {
  return [
    ...stressEventChartRanges(
      treatments: analysis.chartTreatments,
      start: analysis.chartStart,
      end: analysis.chartEnd,
      messages: context.lang,
    ),
    TimelineChartRange(
      start: analysis.activityStart,
      end: analysis.activityEnd,
      color: Colors.teal,
      alpha: 0.10,
      label: context.lang.activityLegendActivity,
      startIcon: Icons.play_arrow,
      endIcon: Icons.stop,
      startLabel: context.lang.activityRangeStartLabel,
      endLabel: context.lang.activityRangeEndLabel,
    ),
    ...analysis.activityTargets.map((target) {
      return _temporaryTargetRange(context, target);
    }),
  ];
}

TimelineChartRange _temporaryTargetRange(
  BuildContext context,
  TemporaryTarget target,
) {
  return TimelineChartRange(
    start: target.createdAt,
    end: target.createdAt.add(Duration(minutes: target.duration)),
    color: Colors.blue,
    alpha: 0.12,
    label: '${target.targetBottom}-${target.targetTop} mg/dL',
    startIcon: Icons.timer,
    endIcon: Icons.timer_off,
    startLabel: context.lang.tempTargetRangeStartLabel,
    endLabel: context.lang.tempTargetRangeEndLabel,
  );
}

List<TimelineChartEvent> _activityEvents(
  BuildContext context,
  ActivityLogAnalysisData analysis,
) {
  return analysis.chartTreatments.map((treatment) {
    final presentation = treatmentPresentation(context.lang, treatment);
    return TimelineChartEvent(
      timestamp: treatment.createdAt ?? analysis.chartStart,
      icon: presentation.icon,
      color: presentation.color,
      label: presentation.label,
      value: treatment.getParts(),
    );
  }).toList();
}

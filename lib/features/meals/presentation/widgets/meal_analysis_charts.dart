import 'package:flutter/material.dart';

import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../data/models/meal_analysis_data.dart';
import 'meal_details/meal_detail_formatters.dart';
import 'meal_details/meal_detail_icons.dart';

List<TimelineChartEvent> mealTimelineChartEvents(MealAnalysisData analysis) {
  return analysis.timelineEvents.map((event) {
    return TimelineChartEvent(
      timestamp: event.timestamp,
      icon: mealTimelineEventIcon(event.type),
      color: mealTimelineEventColor(event.type),
      label: timelineEventLabel(event),
      value: event.value,
    );
  }).toList();
}

List<TimelineChartRange> mealTimelineChartRanges(MealAnalysisData analysis) {
  return analysis.temporaryTargets.map(_temporaryTargetRange).toList();
}

TimelineChartRange _temporaryTargetRange(TemporaryTarget target) {
  return TimelineChartRange(
    start: target.createdAt,
    end: target.createdAt.add(Duration(minutes: target.duration)),
    color: Colors.blue,
    alpha: 0.12,
    label: '${target.targetBottom}-${target.targetTop} mg/dL',
    startIcon: Icons.timer,
    endIcon: Icons.timer_off,
    startLabel: 'Start temp targetu',
    endLabel: 'Koniec temp targetu',
  );
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';
import 'meal_details/meal_detail_formatters.dart';
import 'meal_details/meal_detail_icons.dart';

List<TimelineChartEvent> mealTimelineChartEvents(
  MealAnalysisData analysis, {
  bool correctionsOnly = false,
}) {
  return analysis.timelineEvents
      .where(
        (event) =>
            !correctionsOnly ||
            event.type == MealTimelineEventType.manualCorrection ||
            event.type == MealTimelineEventType.correction,
      )
      .map((event) {
        return TimelineChartEvent(
          timestamp: event.timestamp,
          icon: mealTimelineEventIcon(event.type),
          color: mealTimelineEventColor(event.type),
          label: timelineEventLabel(event),
          value: event.value,
        );
      })
      .toList();
}

List<TimelineChartRange> mealTimelineChartRanges(
  MealAnalysisData analysis, {
  required MealDetailsData details,
  required AppLocalizations messages,
  required Color eatingColor,
}) {
  final start = details.recordedEatingStartedAt;
  final end = details.recordedEatingEndedAt;
  return [
    ...analysis.temporaryTargets.map(_temporaryTargetRange),
    if (start != null &&
        end != null &&
        end.isAfter(start) &&
        start.isBefore(analysis.chartEnd) &&
        end.isAfter(analysis.chartStart))
      TimelineChartRange(
        start: start,
        end: end,
        color: eatingColor,
        alpha: 0.14,
        label: messages.mealEatingPeriod,
        startIcon: Icons.restaurant,
        endIcon: Icons.done,
        startLabel: messages.mealEatingStart,
        endLabel: messages.mealEatingEnd,
      ),
  ];
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

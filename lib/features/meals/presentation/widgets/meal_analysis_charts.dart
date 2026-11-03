import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/stress_event_chart_ranges.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../meal_analysis/common/charts/meal_target_preparation_range.dart';
import '../../../meal_analysis/common/controllers/meal_target_preparation_controller.dart';
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
            event.type == MealTimelineEventType.bolusWizard ||
            event.type == MealTimelineEventType.correction ||
            event.type == MealTimelineEventType.stress ||
            event.type == MealTimelineEventType.bgCheck,
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
  const controller = MealTargetPreparationController();
  final preparation = controller.build(
    treatments: analysis.targetHistory,
    recordedMealStart: start,
  );
  final periods = controller.periods(analysis.targetHistory);
  return [
    ...stressEventChartRanges(
      treatments: analysis.treatments,
      start: analysis.chartStart,
      end: analysis.chartEnd,
      messages: messages,
    ),
    for (final period in periods)
      if (period.target.createdAt.isBefore(analysis.chartEnd) &&
          period.end.isAfter(analysis.chartStart))
        _temporaryTargetRange(
          period.target,
          period.end,
          messages,
          start: preparation?.target == period.target
              ? preparation!.mealStartedAt
              : null,
        ),
    if (preparation != null)
      mealTargetPreparationRange(preparation, messages, eatingColor),
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

TimelineChartRange _temporaryTargetRange(
  TemporaryTarget target,
  DateTime end,
  AppLocalizations messages, {
  DateTime? start,
}) {
  return TimelineChartRange(
    start: start ?? target.createdAt,
    end: end,
    color: Colors.blue,
    alpha: 0.12,
    label: target.targetBottom == target.targetTop
        ? messages.mealTargetValue(target.targetTop)
        : messages.mealTargetRangeValue(target.targetBottom, target.targetTop),
    startIcon: Icons.timer,
    endIcon: Icons.timer_off,
    startLabel: messages.tempTargetRangeStartLabel,
    endLabel: messages.tempTargetRangeEndLabel,
  );
}

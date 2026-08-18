import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/extended_carb.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';
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
    return TimelineChartEvent(
      timestamp: treatment.createdAt ?? analysis.chartStart,
      icon: treatment.getIcon(),
      color: treatment.getColor(),
      label: _treatmentName(context, treatment),
      value: treatment.getParts(),
    );
  }).toList();
}

String _treatmentName(BuildContext context, Treatment treatment) {
  if (treatment is Meal) return context.lang.activityTreatmentMeal;
  if (treatment is TemporaryTarget) return 'Temp target';
  if (treatment is Treat) return 'Treat';
  if (treatment is ManualBolus) return 'Bolus';
  if (treatment is CorrectionBolus) {
    return context.lang.activityTreatmentCorrection;
  }
  if (treatment is ExtendedCarb) return 'Extended carbs';
  return context.lang.activityTreatmentEvent;
}

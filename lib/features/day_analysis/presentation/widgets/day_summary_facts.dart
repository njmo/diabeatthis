import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../domain/models/day_summary_snapshot.dart';
import 'day_stat_row.dart';

class DaySummaryFacts extends StatelessWidget {
  final DaySummarySnapshot snapshot;
  const DaySummaryFacts({super.key, required this.snapshot});

  static const primary = {
    DaySummaryMetric.glucoseMean,
    DaySummaryMetric.glucoseInRangePercent,
    DaySummaryMetric.totalInsulinUnits,
    DaySummaryMetric.mealCount,
    DaySummaryMetric.lowTreatmentCount,
    DaySummaryMetric.activityMinutes,
  };

  String value(BuildContext context, DaySummaryMetric metric) {
    final number = snapshot.metrics[metric];
    if (number == null) return context.lang.beforeMealUnavailable;
    if (metric == DaySummaryMetric.sensorAgeMinutes ||
        metric == DaySummaryMetric.podAgeMinutes) {
      final duration = Duration(minutes: number.toInt());
      return context.lang.dayDeviceAgeValue(
        duration.inDays,
        duration.inHours % 24,
      );
    }
    final integral =
        metric == DaySummaryMetric.mealCount ||
        metric == DaySummaryMetric.lowTreatmentCount ||
        metric == DaySummaryMetric.smbCount ||
        metric == DaySummaryMetric.nightSmbCount ||
        metric == DaySummaryMetric.activityMinutes;
    return NumberFormat(
      integral ? '0' : '0.0',
      context.lang.localeName,
    ).format(number);
  }

  @override
  Widget build(BuildContext context) {
    final metricLabels = labels(context);
    return Column(
      children: [
        ResponsiveMetricList(
          maxColumns: 2,
          children: [
            for (final metric in primary)
              AnalysisMetric(
                label: metricLabels[metric]!,
                value: value(context, metric),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(context.lang.dayReviewDetails),
          children: [
            for (final metric in snapshot.metrics.keys.where(
              (key) => !primary.contains(key),
            ))
              DayStatRow(
                label: metricLabels[metric]!,
                value: value(context, metric),
              ),
          ],
        ),
      ],
    );
  }

  static Map<DaySummaryMetric, String> labels(BuildContext context) => {
    DaySummaryMetric.totalInsulinUnits:
        context.lang.daySummaryMetricTotalInsulinUnits,
    DaySummaryMetric.glucoseMean: context.lang.daySummaryMetricGlucoseMean,
    DaySummaryMetric.glucoseLowPercent:
        context.lang.daySummaryMetricGlucoseLowPercent,
    DaySummaryMetric.glucoseInRangePercent:
        context.lang.daySummaryMetricGlucoseInRangePercent,
    DaySummaryMetric.glucoseHighPercent:
        context.lang.daySummaryMetricGlucoseHighPercent,
    DaySummaryMetric.glucoseMax: context.lang.daySummaryMetricGlucoseMax,
    DaySummaryMetric.glucoseCoveragePercent:
        context.lang.daySummaryMetricGlucoseCoveragePercent,
    DaySummaryMetric.nightGlucoseMean:
        context.lang.daySummaryMetricNightGlucoseMean,
    DaySummaryMetric.nightInRangePercent:
        context.lang.daySummaryMetricNightInRangePercent,
    DaySummaryMetric.nightGlucoseCoveragePercent:
        context.lang.daySummaryMetricNightGlucoseCoveragePercent,
    DaySummaryMetric.basalUnits: context.lang.daySummaryMetricBasalUnits,
    DaySummaryMetric.basalAddedUnits:
        context.lang.daySummaryMetricBasalAddedUnits,
    DaySummaryMetric.basalReducedUnits:
        context.lang.daySummaryMetricBasalReducedUnits,
    DaySummaryMetric.basalCoveragePercent:
        context.lang.daySummaryMetricBasalCoveragePercent,
    DaySummaryMetric.bolusUnits: context.lang.daySummaryMetricBolusUnits,
    DaySummaryMetric.smbUnits: context.lang.daySummaryMetricSmbUnits,
    DaySummaryMetric.smbCount: context.lang.daySummaryMetricSmbCount,
    DaySummaryMetric.nightBasalUnits:
        context.lang.daySummaryMetricNightBasalUnits,
    DaySummaryMetric.nightBasalCoveragePercent:
        context.lang.daySummaryMetricNightBasalCoveragePercent,
    DaySummaryMetric.nightBolusUnits:
        context.lang.daySummaryMetricNightBolusUnits,
    DaySummaryMetric.nightSmbUnits: context.lang.daySummaryMetricNightSmbUnits,
    DaySummaryMetric.nightSmbCount: context.lang.daySummaryMetricNightSmbCount,
    DaySummaryMetric.mealCount: context.lang.managementMealsTab,
    DaySummaryMetric.netCarbsGrams: context.lang.daySummaryMetricNetCarbsGrams,
    DaySummaryMetric.proteinGrams: context.lang.daySummaryMetricProteinGrams,
    DaySummaryMetric.fatGrams: context.lang.daySummaryMetricFatGrams,
    DaySummaryMetric.lowTreatmentCount: context.lang.activityExtraTreatLabel,
    DaySummaryMetric.lowTreatmentCarbsGrams:
        context.lang.daySummaryMetricLowTreatmentCarbsGrams,
    DaySummaryMetric.activityMinutes:
        context.lang.daySummaryMetricActivityMinutes,
    DaySummaryMetric.sensorAgeMinutes: context.lang.daySensorAge,
    DaySummaryMetric.podAgeMinutes: context.lang.daySummaryMetricPodAgeMinutes,
  };
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../domain/models/day_summary_snapshot.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_archived_glucose_ranges.dart';
import 'day_insulin_breakdown.dart';
import 'day_meals_overview.dart';
import 'day_metric_grid.dart';
import 'day_summary_card.dart';

class DaySummaryFacts extends StatelessWidget {
  final DaySummarySnapshot snapshot;
  const DaySummaryFacts({super.key, required this.snapshot});

  String value(BuildContext context, DaySummaryMetric metric) {
    final number = snapshot.observedMetric(metric);
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
    return DayStatFormatter(
      context.lang.localeName,
    ).number(number, decimals: integral ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final metricLabels = labels(context);
    final format = DayStatFormatter(lang.localeName);
    Widget grid(List<DaySummaryMetric> metrics) => DayMetricGrid(
      children: [
        for (final metric in metrics)
          AnalysisMetric(
            label: metricLabels[metric]!,
            value: value(context, metric),
          ),
      ],
    );
    Widget details(List<DaySummaryMetric> metrics) => ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(lang.dayReviewDetails),
      children: [grid(metrics)],
    );
    return Column(
      children: [
        DaySummaryCard(
          title: lang.dayGlucoseTitle,
          information: lang.dayReviewDataNote,
          children: [
            DayArchivedGlucoseRanges(
              coverage: snapshot
                  .metrics[DaySummaryMetric.glucoseCoveragePercent]
                  ?.toDouble(),
              inRange: snapshot.metrics[DaySummaryMetric.glucoseInRangePercent]
                  ?.toDouble(),
              aboveRange: snapshot.metrics[DaySummaryMetric.glucoseHighPercent]
                  ?.toDouble(),
              belowRange: snapshot.metrics[DaySummaryMetric.glucoseLowPercent]
                  ?.toDouble(),
            ),
            const SizedBox(height: 16),
            grid([
              DaySummaryMetric.glucoseMean,
              DaySummaryMetric.glucoseMax,
              DaySummaryMetric.glucoseCoveragePercent,
            ]),
          ],
        ),
        DaySummaryCard(
          title: lang.dayInsulinTitle,
          information: lang.dayInsulinLimit,
          warnings: [
            if (snapshot.metrics[DaySummaryMetric.basalCoveragePercent] != 100)
              '${lang.dayBasalCoverage}: ${format.percent(snapshot.metrics[DaySummaryMetric.basalCoveragePercent], decimals: 1)}',
          ],
          children: [
            grid([DaySummaryMetric.totalInsulinUnits]),
            const SizedBox(height: 16),
            DayInsulinBreakdown(
              basal: snapshot
                  .observedMetric(DaySummaryMetric.basalUnits)
                  ?.toDouble(),
              boluses: snapshot.metrics[DaySummaryMetric.bolusUnits]
                  ?.toDouble(),
              smb: snapshot.metrics[DaySummaryMetric.smbUnits]?.toDouble(),
            ),
            details([
              DaySummaryMetric.bolusUnits,
              DaySummaryMetric.smbCount,
              DaySummaryMetric.basalAddedUnits,
              DaySummaryMetric.basalReducedUnits,
              DaySummaryMetric.basalCoveragePercent,
            ]),
          ],
        ),
        DaySummaryCard(
          title: lang.dayNightSectionTitle,
          children: [
            grid([
              DaySummaryMetric.nightGlucoseMean,
              DaySummaryMetric.nightInRangePercent,
              DaySummaryMetric.nightBasalUnits,
              DaySummaryMetric.nightBolusUnits,
            ]),
            details([
              DaySummaryMetric.nightSmbUnits,
              DaySummaryMetric.nightSmbCount,
              DaySummaryMetric.nightGlucoseCoveragePercent,
              DaySummaryMetric.nightBasalCoveragePercent,
            ]),
          ],
        ),
        DaySummaryCard(
          title: lang.dayMealsTitle,
          information: lang.dayLocalMealsNote,
          children: [
            DayMealsOverview(
              mealCount: snapshot.observedMetric(DaySummaryMetric.mealCount),
              netCarbs: snapshot
                  .observedMetric(DaySummaryMetric.netCarbsGrams)
                  ?.toDouble(),
              protein: snapshot
                  .observedMetric(DaySummaryMetric.proteinGrams)
                  ?.toDouble(),
              fat: snapshot
                  .observedMetric(DaySummaryMetric.fatGrams)
                  ?.toDouble(),
              lowCount: snapshot.observedMetric(
                DaySummaryMetric.lowTreatmentCount,
              ),
              lowCarbs: snapshot
                  .observedMetric(DaySummaryMetric.lowTreatmentCarbsGrams)
                  ?.toDouble(),
            ),
          ],
        ),
        DaySummaryCard(
          title: lang.dayActivityTitle,
          children: [
            grid([DaySummaryMetric.activityMinutes]),
          ],
        ),
        DaySummaryCard(
          title: lang.dayDevicesTitle,
          information: lang.dayDeviceAgeSource,
          children: [
            grid([
              DaySummaryMetric.sensorAgeMinutes,
              DaySummaryMetric.podAgeMinutes,
            ]),
          ],
        ),
      ],
    );
  }

  static Map<DaySummaryMetric, String> labels(BuildContext context) => {
    DaySummaryMetric.totalInsulinUnits:
        context.lang.daySummaryMetricTotalInsulinUnits,
    DaySummaryMetric.glucoseMean: context.lang.daySummaryMetricGlucoseMean,
    DaySummaryMetric.glucoseMax: context.lang.daySummaryMetricGlucoseMax,
    DaySummaryMetric.glucoseCoveragePercent:
        context.lang.daySummaryMetricGlucoseCoveragePercent,
    DaySummaryMetric.nightGlucoseMean:
        context.lang.daySummaryMetricNightGlucoseMean,
    DaySummaryMetric.nightInRangePercent:
        context.lang.daySummaryMetricNightInRangePercent,
    DaySummaryMetric.nightGlucoseCoveragePercent:
        context.lang.daySummaryMetricNightGlucoseCoveragePercent,
    DaySummaryMetric.basalAddedUnits:
        context.lang.daySummaryMetricBasalAddedUnits,
    DaySummaryMetric.basalReducedUnits:
        context.lang.daySummaryMetricBasalReducedUnits,
    DaySummaryMetric.basalCoveragePercent:
        context.lang.daySummaryMetricBasalCoveragePercent,
    DaySummaryMetric.bolusUnits: context.lang.daySummaryMetricBolusUnits,
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

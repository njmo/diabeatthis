import 'package:flutter/material.dart';

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
    if (number == null) return 'Brak danych';
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
    return number.toStringAsFixed(integral ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ResponsiveMetricList(
        maxColumns: 2,
        children: [
          for (final metric in primary)
            AnalysisMetric(
              label: labels[metric]!,
              value: value(context, metric),
            ),
        ],
      ),
      ExpansionTile(
        title: const Text('Szczegółowe statystyki'),
        children: [
          for (final metric in snapshot.metrics.keys.where(
            (key) => !primary.contains(key),
          ))
            DayStatRow(label: labels[metric]!, value: value(context, metric)),
        ],
      ),
    ],
  );

  static const labels = <DaySummaryMetric, String>{
    DaySummaryMetric.totalInsulinUnits: 'Insulina odtworzona · j.',
    DaySummaryMetric.glucoseMean: 'Średnia · mg/dl',
    DaySummaryMetric.glucoseLowPercent: 'Poniżej 70 · %',
    DaySummaryMetric.glucoseInRangePercent: '70–180 · %',
    DaySummaryMetric.glucoseHighPercent: 'Powyżej 180 · %',
    DaySummaryMetric.glucoseMax: 'Maksimum · mg/dl',
    DaySummaryMetric.glucoseCoveragePercent: 'Historia CGM · %',
    DaySummaryMetric.nightGlucoseMean: 'Średnia w nocy · mg/dl',
    DaySummaryMetric.nightInRangePercent: 'Noc 70–180 · %',
    DaySummaryMetric.nightGlucoseCoveragePercent: 'CGM w nocy · %',
    DaySummaryMetric.basalUnits: 'Baza odtworzona · j.',
    DaySummaryMetric.basalAddedUnits: 'Ponad profil · j.',
    DaySummaryMetric.basalReducedUnits: 'Poniżej profilu · j.',
    DaySummaryMetric.basalCoveragePercent: 'Historia bazy · %',
    DaySummaryMetric.bolusUnits: 'Bolusy łącznie · j.',
    DaySummaryMetric.smbUnits: 'SMB · j.',
    DaySummaryMetric.smbCount: 'Liczba SMB',
    DaySummaryMetric.nightBasalUnits: 'Baza w nocy · j.',
    DaySummaryMetric.nightBasalCoveragePercent: 'Baza w nocy · % historii',
    DaySummaryMetric.nightBolusUnits: 'Bolusy w nocy · j.',
    DaySummaryMetric.nightSmbUnits: 'SMB w nocy · j.',
    DaySummaryMetric.nightSmbCount: 'Liczba SMB w nocy',
    DaySummaryMetric.mealCount: 'Posiłki',
    DaySummaryMetric.netCarbsGrams: 'Węglowodany netto · g',
    DaySummaryMetric.proteinGrams: 'Białko · g',
    DaySummaryMetric.fatGrams: 'Tłuszcz · g',
    DaySummaryMetric.lowTreatmentCount: 'Dosłodzenia',
    DaySummaryMetric.lowTreatmentCarbsGrams: 'Dosłodzenia · g WW',
    DaySummaryMetric.activityMinutes: 'Aktywność · min',
    DaySummaryMetric.sensorAgeMinutes: 'Wiek sensora',
    DaySummaryMetric.podAgeMinutes: 'Wiek poda',
  };
}

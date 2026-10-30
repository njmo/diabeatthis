import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../domain/models/day_context.dart';
import 'day_metric_grid.dart';
import 'day_summary_card.dart';

class DayDeviceAgeCard extends StatelessWidget {
  final DayContext day;
  const DayDeviceAgeCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    String age(Duration? value, DayDataSource source) {
      if (day.failedSources.contains(source)) return lang.daySourceUnavailable;
      if (value == null) return lang.dayDeviceAgeUnknown;
      return lang.dayDeviceAgeValue(value.inDays, value.inHours % 24);
    }

    return DaySummaryCard(
      title: lang.dayDevicesTitle,
      information: lang.dayDeviceAgeSource,
      warnings: [
        if (day.sensorAge == null ||
            day.failedSources.contains(DayDataSource.sensorAge))
          '${lang.daySensorAge}: ${age(day.sensorAge, DayDataSource.sensorAge)}',
        if (day.podAge == null ||
            day.failedSources.contains(DayDataSource.podAge))
          '${lang.dayPodAge}: ${age(day.podAge, DayDataSource.podAge)}',
      ],
      children: [
        DayMetricGrid(
          children: [
            AnalysisMetric(
              label: lang.daySensorAge,
              icon: Icons.sensors,
              value: age(day.sensorAge, DayDataSource.sensorAge),
            ),
            AnalysisMetric(
              label: lang.dayPodAge,
              icon: Icons.medical_services_outlined,
              value: age(day.podAge, DayDataSource.podAge),
            ),
          ],
        ),
      ],
    );
  }
}

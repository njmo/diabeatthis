import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/day_context.dart';
import 'day_stat_row.dart';
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
      warnings: [
        if (day.sensorAge == null ||
            day.failedSources.contains(DayDataSource.sensorAge))
          '${lang.daySensorAge}: ${age(day.sensorAge, DayDataSource.sensorAge)}',
        if (day.podAge == null ||
            day.failedSources.contains(DayDataSource.podAge))
          '${lang.dayPodAge}: ${age(day.podAge, DayDataSource.podAge)}',
      ],
      children: [
        DayStatRow(
          label: lang.daySensorAge,
          value: age(day.sensorAge, DayDataSource.sensorAge),
        ),
        DayStatRow(
          label: lang.dayPodAge,
          value: age(day.podAge, DayDataSource.podAge),
        ),
        Text(
          lang.dayDeviceAgeSource,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

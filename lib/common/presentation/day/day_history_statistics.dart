import 'package:flutter/material.dart';

import '../../../features/day_analysis/domain/models/day_context.dart';
import 'day_device_age_card.dart';
import 'day_glucose_chart.dart';
import 'day_insulin_card.dart';
import 'day_night_summary_card.dart';
import 'day_quick_metrics.dart';

/// Factual sections shared by both roles; no local review or therapy actions.
class DayHistoryStatistics extends StatelessWidget {
  const DayHistoryStatistics({super.key, required this.day});
  final DayContext day;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: dayHistoryStatisticCards(context, day),
  );
}

/// Preserve the child's existing lazy ListView while sharing the same cards.
List<Widget> dayHistoryStatisticCards(BuildContext context, DayContext day) => [
  DayDeviceAgeCard(day: day),
  DayQuickMetrics(day: day),
  const SizedBox(height: 12),
  DayGlucoseChart(day: day),
  DayInsulinCard(summary: day.boluses, basal: day.basal),
  const SizedBox(height: 12),
  DayNightSummaryCard(day: day),
  DayInsulinCard(
    summary: day.nightBoluses,
    basal: day.nightBasal,
    isNight: true,
  ),
];

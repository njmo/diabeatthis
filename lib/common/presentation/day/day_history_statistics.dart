import 'package:flutter/material.dart';

import '../../../features/day_analysis/domain/models/day_context.dart';
import '../../../features/day_analysis/presentation/widgets/day_device_age_card.dart';
import '../../../features/day_analysis/presentation/widgets/day_glucose_card.dart';
import '../../../features/day_analysis/presentation/widgets/day_insulin_card.dart';
import '../../l10n/language.dart';

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
  DayGlucoseCard(
    title: context.lang.dayNightTitle,
    summary: day.nightGlucose,
    information: context.lang.dayNightNote,
  ),
  DayInsulinCard(
    summary: day.nightBoluses,
    basal: day.nightBasal,
    isNight: true,
  ),
  DayGlucoseCard(title: context.lang.dayGlucoseTitle, summary: day.glucose),
  DayInsulinCard(summary: day.boluses, basal: day.basal),
];

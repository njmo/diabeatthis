import 'package:flutter/material.dart';
import '../../../../common/l10n/language.dart';
import '../../domain/models/day_context.dart';
import 'day_stat_row.dart';
import 'day_summary_card.dart';

class DayMealsCard extends StatelessWidget {
  final DayContext day;
  const DayMealsCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final meals = day.meals;
    final lows = day.lowTreatments;
    final knownLows = lows?.where((x) => x.netCarbsGrams != null).toList();
    final lowCarbs = knownLows?.fold(0.0, (sum, x) => sum + x.netCarbsGrams!);
    String grams(double? value) =>
        value == null ? '—' : '${value.toStringAsFixed(1)} g';
    final hasMacros =
        meals != null &&
        (meals.count == 0 || meals.count > meals.missingSnapshotCount);
    return DaySummaryCard(
      title: lang.dayMealsTitle,
      children: [
        DayStatRow(
          label: lang.dayMealsCount,
          value: meals?.count.toString() ?? '—',
        ),
        DayStatRow(
          label: lang.dayCarbs,
          value: grams(hasMacros ? meals.netCarbs : null),
        ),
        DayStatRow(
          label: lang.dayProtein,
          value: grams(hasMacros ? meals.protein : null),
        ),
        DayStatRow(
          label: lang.dayFat,
          value: grams(hasMacros ? meals.fat : null),
        ),
        if (meals == null) Text(lang.daySourceUnavailable),
        if (meals != null &&
            (meals.plannedFallbackCount > 0 || meals.missingSnapshotCount > 0))
          Text(
            lang.dayMacroLimit(
              meals.plannedFallbackCount,
              meals.missingSnapshotCount,
            ),
          ),
        DayStatRow(
          label: lang.dayLowCount,
          value: lows?.length.toString() ?? '—',
        ),
        DayStatRow(label: lang.dayLowCarbs, value: grams(lowCarbs)),
        if (lows == null)
          Text(lang.daySourceUnavailable)
        else if (knownLows!.length < lows.length)
          Text(lang.dayLowUnknown),
        Text(
          lang.dayLocalMealsNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

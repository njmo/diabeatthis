import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../domain/models/day_context.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_metric_grid.dart';
import 'day_summary_card.dart';

class DayMealsCard extends StatelessWidget {
  final DayContext day;
  const DayMealsCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final meals = day.meals;
    final lows = day.lowTreatments;
    final knownLows = lows?.where((x) => x.netCarbsGrams != null).toList();
    final lowCarbs = knownLows?.fold(0.0, (sum, x) => sum + x.netCarbsGrams!);
    final grams = format.grams;
    final hasMacros =
        meals != null &&
        (meals.count == 0 || meals.count > meals.missingSnapshotCount);
    return DaySummaryCard(
      title: lang.dayMealsTitle,
      information: lang.dayLocalMealsNote,
      warnings: [
        if (meals == null)
          '${lang.dayMealsCount}: ${lang.daySourceUnavailable}',
        if (lows == null) '${lang.dayLowCount}: ${lang.daySourceUnavailable}',
        if (meals != null &&
            (meals.plannedFallbackCount > 0 || meals.missingSnapshotCount > 0))
          lang.dayMacroLimit(
            meals.plannedFallbackCount,
            meals.missingSnapshotCount,
          ),
        if (lows != null && knownLows!.length < lows.length) lang.dayLowUnknown,
      ],
      children: [
        DayMetricGrid(
          children: [
            AnalysisMetric(
              label: lang.dayMealsCount,
              value: meals?.count.toString() ?? '—',
            ),
            AnalysisMetric(
              label: lang.dayCarbs,
              value: grams(hasMacros ? meals.netCarbs : null),
            ),
            AnalysisMetric(
              label: lang.dayProtein,
              value: grams(hasMacros ? meals.protein : null),
            ),
            AnalysisMetric(
              label: lang.dayFat,
              value: grams(hasMacros ? meals.fat : null),
            ),
            AnalysisMetric(
              label: lang.dayLowCount,
              value: lows?.length.toString() ?? '—',
            ),
            AnalysisMetric(label: lang.dayLowCarbs, value: grams(lowCarbs)),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/day_context.dart';
import 'day_meals_overview.dart';
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
        DayMealsOverview(
          mealCount: meals?.count,
          netCarbs: hasMacros ? meals.netCarbs : null,
          protein: hasMacros ? meals.protein : null,
          fat: hasMacros ? meals.fat : null,
          lowCount: lows?.length,
          lowCarbs: lowCarbs,
        ),
      ],
    );
  }
}

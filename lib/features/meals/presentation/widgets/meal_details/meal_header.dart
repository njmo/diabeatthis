import 'package:flutter/material.dart';

import '../../models/meal_metric_view_data.dart';
import '../../models/meal_page_state.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';
import 'meal_metric_components.dart';

class MealHeader extends StatelessWidget {
  final MealPageState state;

  const MealHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final summary = details.preferredSummarySnapshot;
    final stats = state.analysis?.glucoseStats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details.meal.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        MealAnalysisProgressSummary(state: state),
        const SizedBox(height: 12),
        MealMetricGrid(
          wideColumns: 3,
          metrics: [
            MealMetricTileData(
              icon: Icons.monitor_heart_outlined,
              label: 'Szczyt glikemii',
              value: formatMgdl(stats?.peakGlucose),
            ),
            MealMetricTileData(
              icon: Icons.timer_outlined,
              label: 'Czas do szczytu',
              value: formatDurationOffset(stats?.timeToPeak),
            ),
            MealMetricTileData(
              icon: Icons.timeline,
              label: 'Średnia glikemia',
              value: formatMgdl(stats?.averageGlucose?.round()),
            ),
            MealMetricTileData(
              icon: Icons.vaccines_outlined,
              label: 'Insulina łącznie',
              value: formatUnits(
                state.analysis?.totalInsulinUnits ?? details.totalInsulinUnits,
              ),
            ),
            MealMetricTileData(
              icon: Icons.grain,
              label: 'Węglowodany',
              value: formatGrams(summary?.totalCarbsG),
            ),
            MealMetricTileData(
              icon: Icons.check_circle_outline,
              label: 'Czas w zakresie',
              value: formatPercent(stats?.timeInRangePercent),
            ),
          ],
        ),
      ],
    );
  }
}

class MealAnalysisProgressSummary extends StatelessWidget {
  final MealPageState state;

  const MealAnalysisProgressSummary({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    if (!details.meal.isEaten) {
      return HeaderStatusChip(
        icon: mealStatusIcon(details.meal.status),
        label: mealStatusLabel(details.meal.status),
      );
    }
    if (analysis == null) {
      return const HeaderStatusChip(
        icon: Icons.pending_actions,
        label: 'Analiza oczekuje na dane',
      );
    }
    if (!analysis.hasFullGlucoseWindow) {
      return HeaderStatusChip(
        icon: Icons.hourglass_top,
        label: 'Analiza w toku',
        detail: 'zbieranie do ${mealTime(analysis.expectedChartEnd)}',
      );
    }
    return HeaderStatusChip(
      icon: Icons.check_circle,
      label: 'Analiza gotowa',
      detail: 'okno glikemii ${analysis.postMealWindow.inMinutes} min',
    );
  }
}

class HeaderStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;

  const HeaderStatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final text = detail == null ? label : '$label • $detail';
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: Text(text),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../data/models/meal_details_data.dart';
import '../../models/meal_metric_view_data.dart';
import '../../models/meal_page_state.dart';
import '../../utils/meal_extended_carbs_warning.dart';
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
              icon: Icons.more_time,
              label: 'Węglowodany przedłużone',
              value: formatGrams(
                details.advisorDecision?.extendedCarbsGrams.toDouble(),
              ),
            ),
            if (details.hasAddOn)
              MealMetricTileData(
                icon: Icons.add_circle_outline,
                label: 'Dokładka',
                value: formatSignedGrams(details.addOnNetCarbsG),
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
    final chips = [if (details.isCopied) const HeaderStatusChip.copied()];
    if (!details.meal.isEaten) {
      chips.add(
        HeaderStatusChip(
          icon: mealStatusIcon(details.meal.status),
          label: mealStatusLabel(details.meal.status),
        ),
      );
      if (details.hasAddOn) {
        chips.add(const HeaderStatusChip.addOn());
      }
      return MealHeaderStatusRow(chips: chips);
    }
    if (analysis == null) {
      chips.add(
        const HeaderStatusChip(
          icon: Icons.pending_actions,
          label: 'Analiza oczekuje na dane',
        ),
      );
      if (details.hasAddOn) {
        chips.add(const HeaderStatusChip.addOn());
      }
      return MealHeaderStatusRow(chips: chips);
    }
    if (!analysis.hasFullGlucoseWindow) {
      chips.add(
        HeaderStatusChip(
          icon: Icons.hourglass_top,
          label: 'Analiza w toku',
          detail: 'zbieranie do ${mealTime(analysis.expectedChartEnd)}',
        ),
      );
      if (details.hasAddOn) {
        chips.add(const HeaderStatusChip.addOn());
      }
      return MealHeaderStatusRow(chips: chips);
    }
    chips.add(
      HeaderStatusChip(
        icon: Icons.check_circle,
        label: 'Analiza gotowa',
        detail: 'okno glikemii ${analysis.postMealWindow.inMinutes} min',
      ),
    );
    if (shouldShowMissingExtendedCarbsWarning(
      details: details,
      analysis: analysis,
    )) {
      chips.add(const HeaderStatusChip.missingExtendedCarbs());
    }
    if (_shouldShowWaitTimeIgnoredChip(details.advisorDecision)) {
      chips.add(const HeaderStatusChip.waitTimeIgnored());
    }
    if (details.hasAddOn) {
      chips.add(const HeaderStatusChip.addOn());
    }
    return MealHeaderStatusRow(chips: chips);
  }
}

bool _shouldShowWaitTimeIgnoredChip(MealAdvisorDecisionData? decision) {
  return decision?.result == 'bolused-waiting' &&
      decision?.waitTimeIgnored == true;
}

class MealHeaderStatusRow extends StatelessWidget {
  final List<HeaderStatusChip> chips;

  const MealHeaderStatusRow({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
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

  const HeaderStatusChip.addOn({super.key})
    : icon = Icons.add_circle_outline,
      label = 'Dokładka',
      detail = 'uwzględniona w posiłku';

  const HeaderStatusChip.copied({super.key})
    : icon = Icons.content_copy,
      label = 'Skopiowany',
      detail = null;

  const HeaderStatusChip.missingExtendedCarbs({super.key})
    : icon = Icons.warning_amber_rounded,
      label = 'Nie podano extended carbs na WBT',
      detail = null;

  const HeaderStatusChip.waitTimeIgnored({super.key})
    : icon = Icons.fast_forward_outlined,
      label = 'Czekanie pominięte',
      detail = null;

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

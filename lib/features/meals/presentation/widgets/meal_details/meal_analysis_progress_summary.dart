import 'package:flutter/material.dart';

import '../../../data/models/meal_details_data.dart';
import '../../models/meal_page_state.dart';
import '../../utils/meal_extended_carbs_warning.dart';
import 'header_status_chip.dart';
import 'header_status_chip_type.dart';
import 'meal_detail_formatters.dart';
import 'meal_detail_icons.dart';
import 'meal_header_status_row.dart';

class MealAnalysisProgressSummary extends StatelessWidget {
  final MealPageState state;
  final bool showCompletedStatus;

  const MealAnalysisProgressSummary({
    super.key,
    required this.state,
    this.showCompletedStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    final chips = [if (details.isCopied) const HeaderStatusChip.copied()];
    if (details.hasLowTreatments) {
      chips.add(const HeaderStatusChip.lowTreatment());
    }
    if (!details.meal.isEaten) {
      chips.add(
        HeaderStatusChip(
          icon: mealStatusIcon(details.meal.status),
          label: mealStatusLabel(details.meal.status),
        ),
      );
      if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
      return MealHeaderStatusRow(chips: chips);
    }
    if (analysis == null) {
      chips.add(
        const HeaderStatusChip(
          icon: Icons.pending_actions,
          label: '',
          type: HeaderStatusChipType.analysisPending,
        ),
      );
      if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
      return MealHeaderStatusRow(chips: chips);
    }
    if (!analysis.hasFullGlucoseWindow) {
      chips.add(
        HeaderStatusChip(
          icon: Icons.hourglass_top,
          label: '',
          detail: mealTime(analysis.expectedChartEnd),
          type: HeaderStatusChipType.analysisInProgress,
        ),
      );
      if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
      return MealHeaderStatusRow(chips: chips);
    }
    if (showCompletedStatus) {
      chips.add(
        HeaderStatusChip(
          icon: Icons.check_circle,
          label: '',
          detail: analysis.postMealWindow.inMinutes.toString(),
          type: HeaderStatusChipType.analysisReady,
        ),
      );
    }
    if (shouldShowMissingExtendedCarbsWarning(
      details: details,
      analysis: analysis,
    )) {
      chips.add(const HeaderStatusChip.missingExtendedCarbs());
    }
    if (_shouldShowWaitTimeIgnoredChip(details.advisorDecision)) {
      chips.add(const HeaderStatusChip.waitTimeIgnored());
    }
    if (details.hasAddOn) chips.add(const HeaderStatusChip.addOn());
    return MealHeaderStatusRow(chips: chips);
  }
}

bool _shouldShowWaitTimeIgnoredChip(MealAdvisorDecisionData? decision) {
  return decision?.result == 'bolused-waiting' &&
      decision?.waitTimeIgnored == true;
}

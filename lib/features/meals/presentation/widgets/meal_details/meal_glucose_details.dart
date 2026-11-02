import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../controllers/meal_details_controller.dart';
import '../../models/meal_page_state.dart';
import 'meal_charts_section.dart';
import 'meal_outcome_section.dart';

/// Keeps chart selection live while its modal route is open.
class MealGlucoseDetails extends ConsumerWidget {
  final MealPageState initialState;
  const MealGlucoseDetails({super.key, required this.initialState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref
            .watch(mealDetailsControllerProvider(initialState.details.meal.id))
            .asData
            ?.value ??
        initialState;
    final chart = MealChartsSection(
      details: state.details,
      analysis: state.analysis,
      analysisError: state.analysisError,
      selectedTimestamp: state.selectedTimestamp,
      advanced: true,
    );
    return state.analysis?.hasFullGlucoseWindow == true
        ? MealOutcomeSection(
            analysis: state.analysis!,
            advanced: true,
            chart: chart,
          )
        : chart;
  }
}

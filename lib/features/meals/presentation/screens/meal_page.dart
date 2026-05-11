import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/meal_details_controller.dart';
import '../models/meal_page_state.dart';
import '../widgets/meal_details/meal_activity_analysis_section.dart';
import '../widgets/meal_details/meal_advisor_result_section.dart';
import '../widgets/meal_details/meal_basic_info_section.dart';
import '../widgets/meal_details/meal_charts_section.dart';
import '../widgets/meal_details/meal_header.dart';
import '../widgets/meal_details/meal_nutrition_analysis_section.dart';
import '../widgets/meal_details/meal_snapshots_section.dart';
import '../widgets/meal_details/meal_transition_analysis_section.dart';

@RoutePage()
class MealPage extends ConsumerWidget {
  final int mealId;

  const MealPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealDetailsControllerProvider(mealId));

    return Scaffold(
      appBar: AppBar(
        title: state.maybeWhen(
          data: (value) => Text(value.details.meal.name),
          orElse: () => Text('Posiłek $mealId'),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Błąd: $error')),
        data: (value) => MealPageBody(state: value),
      ),
    );
  }
}

class MealPageBody extends ConsumerWidget {
  final MealPageState state;

  const MealPageBody({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = state.details;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MealHeader(state: state),
        const SizedBox(height: 12),
        MealBasicInfoSection(details: details),
        MealNutritionAnalysisSection(details: details),
        MealAdvisorResultSection(details: details),
        if (details.meal.isEaten)
          MealChartsSection(
            details: details,
            analysis: state.analysis,
            analysisError: state.analysisError,
            selectedTimestamp: state.selectedTimestamp,
          ),
        if (details.meal.isEaten && state.analysis != null)
          MealActivityAnalysisSection(
            mealId: details.meal.id,
            analysis: state.analysis!,
            selectedTimestamp: state.selectedTimestamp,
          ),
        MealTransitionAnalysisSection(details: details),
        MealSnapshotsSection(details: details),
      ],
    );
  }
}

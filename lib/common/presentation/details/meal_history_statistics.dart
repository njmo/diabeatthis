import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../features/meals/data/models/meal_analysis_data.dart';
import '../../../features/meals/data/models/meal_details_data.dart';
import '../../../features/meals/presentation/widgets/meal_details/meal_charts_section.dart';
import '../../../features/meals/presentation/widgets/meal_details/meal_observation_context.dart';
import '../../../features/meals/presentation/widgets/meal_details/meal_outcome_section.dart';

/// Shared factual Nightscout statistics, independent of patient workflows/AI.
class MealHistoryStatistics extends HookWidget {
  const MealHistoryStatistics({
    super.key,
    required this.details,
    required this.data,
  });
  final MealDetailsData details;
  final MealAnalysisData data;

  @override
  Widget build(BuildContext context) {
    final selected = useState<DateTime?>(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealOutcomeSection(
          analysis: data,
          hasLocalContext: false,
          advanced: true,
          chart: MealChartsSection(
            details: details,
            analysis: data,
            analysisError: null,
            selectedTimestamp: selected.value,
            advanced: true,
            onTimestampSelected: (time) => selected.value = time,
          ),
        ),
        const SizedBox(height: 16),
        MealObservationContext(analysis: data),
      ],
    );
  }
}

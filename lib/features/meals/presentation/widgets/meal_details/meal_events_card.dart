import 'package:flutter/material.dart';

import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_activity_analysis_section.dart';
import 'meal_low_treatments_section.dart';
import 'meal_observation_context.dart';

class MealEventsCard extends StatelessWidget {
  final MealDetailsData details;
  final MealAnalysisData analysis;
  final ValueChanged<DateTime> onSelected;
  final DateTime? selectedTimestamp;
  const MealEventsCard({
    super.key,
    required this.details,
    required this.analysis,
    required this.onSelected,
    this.selectedTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealActivityAnalysisSection(
          mealId: details.meal.id,
          analysis: analysis,
          selectedTimestamp: selectedTimestamp,
          onTimestampSelected: onSelected,
        ),
        MealLowTreatmentsSection(details: details),
        MealObservationContext(analysis: analysis),
      ],
    );
  }
}

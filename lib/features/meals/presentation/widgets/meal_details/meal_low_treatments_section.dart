import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../low_treatment/presentation/widgets/low_treatment_details_tile.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealLowTreatmentsSection extends StatelessWidget {
  const MealLowTreatmentsSection({super.key, required this.details});

  final MealDetailsData details;

  @override
  Widget build(BuildContext context) {
    if (details.lowTreatments.isEmpty) {
      return const SizedBox.shrink();
    }

    return MealSectionTile(
      title: context.lang.activityExtraTreatLabel,
      initiallyExpanded: true,
      children: [
        for (final treatment in details.lowTreatments)
          MealLowTreatmentTile(
            treatment: treatment,
            parentMealTime: details.meal.eatenOrPlannedAt,
          ),
      ],
    );
  }
}

class MealLowTreatmentTile extends StatelessWidget {
  const MealLowTreatmentTile({
    super.key,
    required this.treatment,
    required this.parentMealTime,
  });

  final MealLowTreatmentDetailsData treatment;
  final DateTime parentMealTime;

  @override
  Widget build(BuildContext context) {
    return LowTreatmentDetailsTile(
      contentPadding: EdgeInsets.zero,
      treatment: treatment,
      timeLabel: _timeLabel(),
    );
  }

  String _timeLabel() {
    final treatmentTime = treatment.meal.eatenOrPlannedAt;
    final delay = treatmentTime.difference(parentMealTime);
    return '${mealTime(treatmentTime)} • ${formatDelayAfterMeal(delay)}';
  }
}

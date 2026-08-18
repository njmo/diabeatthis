import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_section_card.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_details_tile.dart';
import '../../../meals/data/models/meal_details_data.dart';
import '../../../meals/presentation/widgets/meal_details/meal_detail_formatters.dart';

class ActivityLowTreatmentsSection extends StatelessWidget {
  const ActivityLowTreatmentsSection({
    super.key,
    required this.lowTreatments,
    required this.activityStart,
  });

  final List<MealLowTreatmentDetailsData> lowTreatments;
  final DateTime activityStart;

  @override
  Widget build(BuildContext context) {
    if (lowTreatments.isEmpty) {
      return const SizedBox.shrink();
    }

    return DetailSectionCard(
      title: context.lang.activityExtraTreatLabel,
      children: [
        for (final treatment in lowTreatments)
          ActivityLowTreatmentTile(
            treatment: treatment,
            activityStart: activityStart,
          ),
      ],
    );
  }
}

class ActivityLowTreatmentTile extends StatelessWidget {
  const ActivityLowTreatmentTile({
    super.key,
    required this.treatment,
    required this.activityStart,
  });

  final MealLowTreatmentDetailsData treatment;
  final DateTime activityStart;

  @override
  Widget build(BuildContext context) {
    return LowTreatmentDetailsTile(
      treatment: treatment,
      timeLabel: _timeLabel(context),
    );
  }

  String _timeLabel(BuildContext context) {
    final treatmentTime = treatment.meal.eatenOrPlannedAt;
    final delay = treatmentTime.difference(activityStart);
    return '${mealTime(treatmentTime)} • ${_formatDelayAfterStart(context, delay)}';
  }
}

String _formatDelayAfterStart(BuildContext context, Duration duration) {
  final minutes = duration.inMinutes.abs();
  if (duration.isNegative) {
    return context.lang.activityDelayBeforeStart(minutes);
  }
  return context.lang.activityDelayAfterStart(minutes);
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../domain/models/meal_target_preparation.dart';

class MealTargetPreparationNote extends StatelessWidget {
  const MealTargetPreparationNote({super.key, required this.preparation});
  final MealTargetPreparation preparation;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.track_changes_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          context.lang.mealTargetPreparationLead(
            formatDurationLabel(preparation.leadTime),
            TimeOfDay.fromDateTime(
              preparation.target.createdAt.toLocal(),
            ).format(context),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ],
  );
}

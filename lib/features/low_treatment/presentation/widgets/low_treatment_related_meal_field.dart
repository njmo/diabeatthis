import 'package:flutter/material.dart';

import '../../../../core/domain/model/meal.dart';

class LowTreatmentRelatedMealField extends StatelessWidget {
  const LowTreatmentRelatedMealField({
    super.key,
    required this.meal,
    required this.onDetach,
  });

  final Meal meal;
  final VoidCallback? onDetach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plannedAt = meal.plannedAt;
    final timeLabel = plannedAt == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(plannedAt));

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Powiązany posiłek',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Odepnij posiłek',
          onPressed: onDetach,
          icon: const Icon(Icons.close),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            meal.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
          if (timeLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              timeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

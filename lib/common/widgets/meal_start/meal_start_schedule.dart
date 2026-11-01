import 'package:flutter/material.dart';

import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../l10n/language.dart';

class MealStartSchedule extends StatelessWidget {
  const MealStartSchedule({
    super.key,
    required this.grams,
    required this.settings,
  });

  final int grams;
  final ExtendedCarbsScheduleSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.lang.mealStartScheduleLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  formatExtendedCarbsSchedule(grams, settings: settings),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

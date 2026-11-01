import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class MealStartWaitLabel extends StatelessWidget {
  const MealStartWaitLabel({super.key, this.waitMinutes});

  final int? waitMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final minutes = waitMinutes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            minutes == null ? Icons.check_circle_outline : Icons.schedule,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              minutes == null
                  ? context.lang.mealStartNoWaiting
                  : context.lang.mealStartWaitAfterBolus(minutes),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_activity_dose_suggestion.dart';

class MealActivityWarning extends StatelessWidget {
  const MealActivityWarning({super.key, required this.suggestion});
  final MealActivityDoseSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (suggestion.phase) {
      MealActivityPhase.upcoming => context.lang.mealActivityUpcoming,
      MealActivityPhase.ongoing => context.lang.mealActivityOngoing,
      MealActivityPhase.completed => context.lang.mealActivityCompleted,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.amber.shade300
                : const Color(0xFF8D6500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.lang.mealActivityDoseProposal(suggestion.dosePercent),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$label · ${suggestion.activityName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

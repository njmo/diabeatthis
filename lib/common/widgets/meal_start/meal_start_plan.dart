import 'package:flutter/material.dart';

import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../l10n/language.dart';
import '../../meal/meal_decision.dart';
import 'meal_start_wait_label.dart';

class MealStartPlan extends StatelessWidget {
  const MealStartPlan({super.key, required this.advice});

  final MealAdvice advice;

  @override
  Widget build(BuildContext context) {
    final decision = advice.decision;
    if (decision == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = switch (decision) {
      MealDecision.eatNowBolusLater => context.lang.mealStartEatThenBolus,
      MealDecision.bolusAndEatNow => context.lang.mealStartBolusAndEat,
      MealDecision.bolusWaitThenEat => context.lang.mealStartBolusWaitEat,
      MealDecision.bolus => context.lang.mealStartBolusOnly,
    };
    final icon = switch (decision) {
      MealDecision.eatNowBolusLater ||
      MealDecision.bolusAndEatNow => Icons.restaurant_rounded,
      MealDecision.bolusWaitThenEat ||
      MealDecision.bolus => Icons.water_drop_rounded,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: colors.primary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (decision == MealDecision.bolusAndEatNow ||
            (decision == MealDecision.bolusWaitThenEat && advice.wait != null))
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: MealStartWaitLabel(
              waitMinutes: decision == MealDecision.bolusWaitThenEat
                  ? advice.wait!.recommendedMinutes
                  : null,
            ),
          ),
      ],
    );
  }
}

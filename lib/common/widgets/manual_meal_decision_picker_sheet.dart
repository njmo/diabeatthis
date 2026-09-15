import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../meal/manual_meal_decision.dart';
import '../meal/meal_decision.dart';

class ManualMealDecisionPickerSheet extends StatelessWidget {
  final MealDecision selectedDecision;

  const ManualMealDecisionPickerSheet({
    super.key,
    required this.selectedDecision,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              context.lang.uiChooseTheMealSequence,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final decision in [
            MealDecision.eatNowBolusLater,
            MealDecision.bolusAndEatNow,
            MealDecision.bolusWaitThenEat,
          ])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(mealDecisionLabel(decision)),
              selected: decision == selectedDecision,
              trailing: decision == selectedDecision
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(decision),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

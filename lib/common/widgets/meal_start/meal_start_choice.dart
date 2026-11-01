import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../icon_choice_button.dart';

class MealStartChoice extends StatelessWidget {
  const MealStartChoice({super.key, required this.onEat, required this.onSkip});

  final VoidCallback onEat;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: IconChoiceButton(
              icon: Icons.restaurant_outlined,
              label: context.lang.mealStatusEatChoice,
              onPressed: onEat,
              emphasized: true,
            ),
          ),
          const VerticalDivider(width: 1, indent: 24, endIndent: 24),
          Expanded(
            child: IconChoiceButton(
              icon: Icons.no_meals_outlined,
              label: context.lang.mealStatusSkipChoice,
              onPressed: onSkip,
            ),
          ),
        ],
      ),
    ),
  );
}

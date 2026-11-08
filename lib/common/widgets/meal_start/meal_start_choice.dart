import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../icon_choice_pair.dart';

class MealStartChoice extends StatelessWidget {
  const MealStartChoice({super.key, required this.onEat, required this.onSkip});

  final VoidCallback onEat;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => IconChoicePair(
    firstIcon: Icons.restaurant_outlined,
    firstLabel: context.lang.mealStatusEatChoice,
    onFirst: onEat,
    secondIcon: Icons.no_meals_outlined,
    secondLabel: context.lang.mealStatusSkipChoice,
    onSecond: onSkip,
  );
}

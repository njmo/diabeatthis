import 'package:flutter/material.dart';

import '../../../l10n/language.dart';

class MealDecisionAnsweredStatus extends StatelessWidget {
  const MealDecisionAnsweredStatus({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.check_circle_outline,
        size: 18,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.green.shade400
            : Colors.green.shade800,
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(context.lang.mealDecisionStatusAnswered)),
    ],
  );
}

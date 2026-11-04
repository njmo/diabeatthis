import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_clarification_required.dart';

class MealPhotoClarificationCard extends StatelessWidget {
  const MealPhotoClarificationCard({super.key, required this.clarification});
  final MealPhotoClarificationRequired clarification;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.lang.mealPhotoClarificationTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final question in clarification.questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(question),
            ),
          Text(
            context.lang.mealPhotoClarificationHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../l10n/language.dart';

enum MealInterruptionChoice { interrupt, finishEating }

class MealInterruptionDialog extends StatelessWidget {
  final bool canFinishEating;

  const MealInterruptionDialog({super.key, required this.canFinishEating});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.mealInterruptionTitle),
      content: Text(
        canFinishEating
            ? strings.mealInterruptionMessage
            : strings.mealInterruptionNoEatingMessage,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.settingsCancel),
        ),
        if (canFinishEating)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(MealInterruptionChoice.finishEating),
            child: Text(strings.mealProgressFinishEating),
          ),
        FilledButton.tonal(
          onPressed: () =>
              Navigator.of(context).pop(MealInterruptionChoice.interrupt),
          child: Text(strings.mealInterruptionConfirm),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class MealStartActions extends StatelessWidget {
  const MealStartActions({
    super.key,
    required this.confirmAction,
    required this.cancelAction,
    this.showDecisionChange = false,
    this.hasAdvice = false,
    this.opensAaps = false,
    this.onChangeDecision,
  });

  final Widget confirmAction;
  final Widget cancelAction;
  final bool showDecisionChange;
  final bool hasAdvice;
  final bool opensAaps;
  final VoidCallback? onChangeDecision;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showDecisionChange) ...[
        Tooltip(
          message: context.lang.uiChooseADecisionManually,
          child: TextButton.icon(
            onPressed: onChangeDecision,
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: Text(
              hasAdvice
                  ? context.lang.mealStartChangeDecision
                  : context.lang.uiChooseADecisionManually,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      confirmAction,
      if (opensAaps) ...[
        const SizedBox(height: 8),
        Text(
          context.lang.mealStartAapsHandoff,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      cancelAction,
    ],
  );
}

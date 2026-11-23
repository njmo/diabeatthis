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
    this.onAskCaregiver,
  });

  final Widget confirmAction;
  final Widget? cancelAction;
  final bool showDecisionChange;
  final bool hasAdvice;
  final bool opensAaps;
  final VoidCallback? onChangeDecision;
  final VoidCallback? onAskCaregiver;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (onAskCaregiver != null || showDecisionChange) ...[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            if (onAskCaregiver != null)
              TextButton(
                onPressed: onAskCaregiver,
                child: Text(context.lang.mealDecisionDemoAsk),
              ),
            if (showDecisionChange)
              Tooltip(
                message: context.lang.uiChooseADecisionManually,
                child: TextButton(
                  onPressed: onChangeDecision,
                  child: Text(
                    hasAdvice
                        ? context.lang.mealStartChangeDecision
                        : context.lang.uiChooseADecisionManually,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
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
      if (cancelAction != null) cancelAction!,
    ],
  );
}

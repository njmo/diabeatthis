import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class MealAdviceLoading extends StatelessWidget {
  final bool aiAssisted;
  final VoidCallback onManual;
  const MealAdviceLoading({
    super.key,
    required this.aiAssisted,
    required this.onManual,
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const LinearProgressIndicator(),
      const SizedBox(height: 16),
      Text(
        aiAssisted
            ? context.lang.mealAiAssistedContextLoading
            : context.lang.mealAdviceCheckingData,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onManual,
        icon: const Icon(Icons.edit_outlined),
        label: Text(context.lang.uiChooseADecisionManually),
      ),
    ],
  );
}

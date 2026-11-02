import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../current_glucose_summary.dart';

enum MealShortfallAction { saveActual, saveAndCorrect, editAmounts }

class MealShortfallReviewDialog extends StatelessWidget {
  const MealShortfallReviewDialog({
    super.key,
    required this.actualCarbs,
    required this.missingCarbs,
    required this.usesReportedBaseline,
    this.usesBolusCoverage = false,
    this.correctionCarbs = 0,
  });

  final int actualCarbs;
  final int missingCarbs;
  final bool usesReportedBaseline;
  final bool usesBolusCoverage;
  final int correctionCarbs;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AlertDialog(
      scrollable: true,
      title: Text(lang.mealCompletionShortfallTitle),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CurrentGlucoseSummary(),
          const SizedBox(height: 16),
          Text(lang.mealCompletionActualCarbs(actualCarbs)),
          const SizedBox(height: 12),
          if (correctionCarbs >= 0)
            Text(
              usesBolusCoverage
                  ? lang.mealCompletionCoveredShortfall(missingCarbs)
                  : usesReportedBaseline
                  ? lang.mealCompletionReportedShortfall(missingCarbs)
                  : lang.mealSummaryNegativeDescription(missingCarbs),
            ),
          if (correctionCarbs < 0) ...[
            Text(
              lang.mealCompletionCorrectionProposal(correctionCarbs),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(lang.mealCompletionCorrectionExplanation),
          ],
          const SizedBox(height: 20),
          if (correctionCarbs < 0)
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, MealShortfallAction.saveAndCorrect),
              icon: const Icon(Icons.check),
              label: Text(lang.mealCompletionSaveAndCorrect),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(context, MealShortfallAction.editAmounts),
            icon: const Icon(Icons.edit_outlined),
            label: Text(lang.mealCompletionEditOrAdd),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, MealShortfallAction.saveActual),
            child: Text(lang.mealCompletionSaveActual),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../core/domain/model/bolus_wizard.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealWizardHistoryRow extends StatelessWidget {
  final BolusWizard wizard;
  const MealWizardHistoryRow({super.key, required this.wizard});

  @override
  Widget build(BuildContext context) {
    final result = wizard.calculatorResult;
    return MealInfoRow(
      label: 'Kalkulator ${mealDateTime(wizard.createdAt.toLocal())}',
      value:
          '${formatGrams(result?.carbs)} · ${formatUnits(result?.totalInsulin)} · '
          '${result?.percentageCorrection == null ? 'procent nieznany' : '${result!.percentageCorrection}%'}',
    );
  }
}

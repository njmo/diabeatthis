import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../meal/manual_meal_decision.dart';
import '../meal/meal_decision.dart';
import 'manual_meal_decision_picker_field.dart';

class ManualMealDecisionFields extends StatelessWidget {
  final ManualMealDecision value;
  final ValueChanged<ManualMealDecision> onChanged;

  const ManualMealDecisionFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ManualMealDecisionPickerField(
        value: value.decision,
        onChanged: (decision) => onChanged(
          ManualMealDecision(
            decision: decision,
            waitMinutes: decision == MealDecision.bolusWaitThenEat
                ? value.waitMinutes
                : 0,
          ),
        ),
      ),
      if (value.decision == MealDecision.bolusWaitThenEat) ...[
        const SizedBox(height: 12),
        TextFormField(
          initialValue: value.waitMinutes == 0 ? '' : '${value.waitMinutes}',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.lang.uiWaitingTimeAfterInsulinMin,
          ),
          validator: (text) => (int.tryParse(text ?? '') ?? 0) <= 0
              ? context.lang.uiEnterAPositiveNumberOfMinutes
              : null,
          onChanged: (text) => onChanged(
            ManualMealDecision(
              decision: value.decision,
              waitMinutes: int.tryParse(text) ?? 0,
            ),
          ),
        ),
      ],
    ],
  );
}

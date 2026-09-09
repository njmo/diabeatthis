import 'package:flutter/material.dart';

import '../meal/manual_meal_decision.dart';
import '../meal/meal_decision.dart';
import 'manual_meal_decision_picker_sheet.dart';

class ManualMealDecisionPickerField extends StatelessWidget {
  final MealDecision value;
  final ValueChanged<MealDecision> onChanged;

  const ManualMealDecisionPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: () async {
        FocusScope.of(context).unfocus();
        final decision = await showModalBottomSheet<MealDecision>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) =>
              ManualMealDecisionPickerSheet(selectedDecision: value),
        );
        if (decision != null && context.mounted) {
          onChanged(decision);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Decyzja ręczna',
          suffixIcon: Icon(Icons.expand_more),
        ),
        child: Text(mealDecisionLabel(value)),
      ),
    ),
  );
}

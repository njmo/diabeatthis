import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../meal_decision_preferences.dart';

class MealDecisionTimeoutField extends StatelessWidget {
  const MealDecisionTimeoutField({
    super.key,
    required this.value,
    this.onChanged,
    this.allowManualDecision = true,
  });
  final MealDecisionTimeoutFallback value;
  final bool allowManualDecision;
  final ValueChanged<MealDecisionTimeoutFallback>? onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<MealDecisionTimeoutFallback>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.lang.mealDecisionTimeoutSetting,
          helperText: context.lang.mealDecisionTimeoutExplanation,
          helperMaxLines: 4,
        ),
        items: [
          for (final method in MealDecisionTimeoutFallback.values)
            DropdownMenuItem(
              value: method,
              enabled:
                  method != MealDecisionTimeoutFallback.manual ||
                  allowManualDecision,
              child: Text(
                method == MealDecisionTimeoutFallback.app
                    ? context.lang.mealDecisionTimeoutBuiltin
                    : context.lang.uiChooseManually,
              ),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (method) {
                if (method != null) onChanged!(method);
              },
      );
}

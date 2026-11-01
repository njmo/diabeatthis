import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../l10n/language.dart';
import '../meal/manual_meal_decision.dart';
import 'manual_meal_decision_fields.dart';

class ManualMealDecisionDialog extends HookWidget {
  final ManualMealDecision initialValue;
  final bool preservesMealValues;
  final bool showAllDecisions;
  const ManualMealDecisionDialog({
    super.key,
    this.preservesMealValues = false,
    this.showAllDecisions = false,
    this.initialValue = const ManualMealDecision(),
  });

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final value = useState(initialValue);
    return AlertDialog(
      title: Text(
        preservesMealValues
            ? context.lang.mealStartChangeDecision
            : context.lang.uiChooseManually,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ManualMealDecisionFields(
                value: value.value,
                onChanged: (next) => value.value = next,
                showAllDecisions: showAllDecisions,
              ),
              if (preservesMealValues) ...[
                const SizedBox(height: 12),
                Text(
                  context.lang.mealStartValuesUnchanged,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.lang.settingsCancel),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(value.value);
            }
          },
          child: Text(
            preservesMealValues
                ? context.lang.mealStartApplyChange
                : context.lang.addIngredientNext,
          ),
        ),
      ],
    );
  }
}

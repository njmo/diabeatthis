import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../meal/manual_meal_decision.dart';
import 'manual_meal_decision_fields.dart';

class ManualMealDecisionDialog extends HookWidget {
  final ManualMealDecision initialValue;
  const ManualMealDecisionDialog({
    super.key,
    this.initialValue = const ManualMealDecision(),
  });

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final value = useState(initialValue);
    return AlertDialog(
      title: const Text('Wybierz samodzielnie'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: ManualMealDecisionFields(
            value: value.value,
            onChanged: (next) => value.value = next,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(value.value);
            }
          },
          child: const Text('Dalej'),
        ),
      ],
    );
  }
}

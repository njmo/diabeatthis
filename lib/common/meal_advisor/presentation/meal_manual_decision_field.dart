import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class MealManualDecisionField extends StatelessWidget {
  const MealManualDecisionField({
    super.key,
    required this.value,
    this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(context.lang.mealDecisionAllowManual),
    subtitle: Text(context.lang.mealDecisionAllowManualDescription),
    value: value,
    onChanged: onChanged,
  );
}

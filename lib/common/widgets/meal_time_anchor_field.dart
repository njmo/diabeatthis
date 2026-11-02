import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../meal/meal_time_anchor.dart';

class MealTimeAnchorField extends StatelessWidget {
  const MealTimeAnchorField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final MealTimeAnchor value;
  final ValueChanged<MealTimeAnchor> onChanged;

  static String label(BuildContext context, MealTimeAnchor anchor) =>
      switch (anchor) {
        MealTimeAnchor.eatingStart => context.lang.uiEatingStarted,
        MealTimeAnchor.insulin => context.lang.mealFlowInsulinTime,
        MealTimeAnchor.eatingEnd => context.lang.mealFlowEatingEnd,
      };

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<MealTimeAnchor>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: context.lang.mealTimeAnchorLabel,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final anchor in MealTimeAnchor.values)
        DropdownMenuItem(value: anchor, child: Text(label(context, anchor))),
    ],
    onChanged: (anchor) {
      if (anchor != null) onChanged(anchor);
    },
  );
}

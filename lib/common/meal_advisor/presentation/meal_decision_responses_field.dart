import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class MealDecisionResponsesField extends StatelessWidget {
  const MealDecisionResponsesField({
    super.key,
    required this.enabled,
    required this.onChanged,
    this.deferralMinutes = 45,
    this.onDeferralChanged,
  });
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final int deferralMinutes;
  final ValueChanged<int>? onDeferralChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.lang.mealDecisionResponsesTitle),
        subtitle: Text(context.lang.mealDecisionResponsesDescription),
        value: enabled,
        onChanged: onChanged,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: deferralMinutes,
        decoration: InputDecoration(
          labelText: context.lang.mealDecisionDefaultDeferral,
        ),
        items:
            ({15, 30, 45, 60, 90, 120, 180, deferralMinutes}.toList()..sort())
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text(
                      minutes == 45
                          ? context.lang.mealDecisionSchoolLesson
                          : context.lang.mealDecisionDuration(minutes),
                    ),
                  ),
                )
                .toList(),
        onChanged: !enabled || onChanged == null || onDeferralChanged == null
            ? null
            : (value) {
                if (value != null) onDeferralChanged!(value);
              },
      ),
      const SizedBox(height: 12),
      Text(
        context.lang.mealDecisionDeliveryPending,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

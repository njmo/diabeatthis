import 'package:flutter/material.dart';

import '../l10n/language.dart';

class DurationMinutesField extends StatelessWidget {
  const DurationMinutesField({
    super.key,
    required this.controller,
    this.onChanged,
    this.isRequired = true,
    this.maximum,
    this.maximumError,
  });
  final bool isRequired;
  final int? maximum;
  final String? maximumError;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: context.lang.activityDurationLabel,
      helperText: isRequired ? null : context.lang.activityOptionalDurationHint,
      suffixText: context.lang.activityMinutesUnit,
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged,
    validator: (value) {
      final text = value?.trim() ?? '';
      if (!isRequired && text.isEmpty) return null;
      if (maximum != null && (int.tryParse(text) ?? 0) > maximum!) {
        return maximumError ?? context.lang.planningDurationTooLong(maximum!);
      }
      return (int.tryParse(text) ?? 0) <= 0
          ? context.lang.activityDurationRequired
          : null;
    },
  );
}

import 'package:flutter/material.dart';
import '../l10n/language.dart';

class DurationMinutesField extends StatelessWidget {
  const DurationMinutesField({
    super.key,
    required this.controller,
    this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: context.lang.activityDurationLabel,
      suffixText: context.lang.activityMinutesUnit,
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged,
    validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
        ? context.lang.activityDurationRequired
        : null,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NutritionValueTextFormField extends StatelessWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const NutritionValueTextFormField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      maxLength: 30,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      onChanged: onChanged,
      validator: (value) {
        final normalized = value?.trim().replaceAll(',', '.');
        if (normalized == null || normalized.isEmpty) {
          return '';
        }
        final parsed = double.tryParse(normalized);
        if (parsed == null || parsed < 0) {
          return 'Podaj liczbę';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

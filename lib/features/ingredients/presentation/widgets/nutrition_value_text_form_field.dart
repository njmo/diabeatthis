import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/l10n/language.dart';

class NutritionValueTextFormField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextEditingController? controller;
  final IconData? icon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int? maxLength;

  const NutritionValueTextFormField({
    super.key,
    required this.label,
    this.initialValue,
    this.controller,
    this.icon,
    this.onChanged,
    this.validator,
    this.maxLength = 30,
  }) : assert(
         controller == null || initialValue == null,
         'controller and initialValue cannot be used together.',
       );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      maxLength: maxLength,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      onChanged: onChanged,
      validator: validator ?? _validateNutritionValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  String? _validateNutritionValue(String? value) {
    final normalized = value?.trim().replaceAll(',', '.');
    if (normalized == null || normalized.isEmpty) {
      return '';
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return lang.ingredientNumberRequired;
    }
    return null;
  }
}

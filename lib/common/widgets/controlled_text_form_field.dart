import 'package:flutter/material.dart';

import 'controlled_text_form_field_state.dart';

/// A text form field that accepts external updates without resetting user edits.
class ControlledTextFormField extends StatefulWidget {
  const ControlledTextFormField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSaved,
    this.validator,
    this.decoration = const InputDecoration(),
    this.maxLength,
    this.textInputAction,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final InputDecoration decoration;
  final int? maxLength;
  final TextInputAction? textInputAction;

  @override
  State<ControlledTextFormField> createState() =>
      ControlledTextFormFieldState();
}

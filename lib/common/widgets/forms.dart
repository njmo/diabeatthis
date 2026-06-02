// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

bool validateForm(GlobalKey<FormState> formKey) {
  return formKey.currentState?.validate() ?? false;
}

class StringFormField extends StatelessWidget {
  const StringFormField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
    this.builder,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final TextFieldBuilder? builder;

  @override
  Widget build(BuildContext context) {
    return _TextField(
      label: label,
      value: value,
      validator: validator,
      onChanged: onChanged,
      builder: (context, controller) {
        if (builder != null) {
          return builder!(context, controller);
        } else {
          return TextFormField(
            controller: controller,
            validator: validator,
            decoration: InputDecoration(labelText: label),
            onChanged: onChanged,
          );
        }
      },
    );
  }
}

typedef TextFieldBuilder =
    Widget Function(BuildContext context, TextEditingController controller);

class _TextField extends StatefulWidget {
  const _TextField({
    required this.value,
    required this.label,
    required this.onChanged,
    this.builder,
    this.validator,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final TextFieldBuilder? builder;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final controller = TextEditingController(text: widget.value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.addListener(() {
        widget.onChanged(controller.text);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return widget.builder!(context, controller);
    } else {
      return TextFormField(
        controller: controller,
        validator: (value) {
          if (widget.validator != null) {
            return widget.validator!(value);
          }
          return null;
        },
        decoration: InputDecoration(labelText: widget.label),
        onChanged: widget.onChanged,
      );
    }
  }
}

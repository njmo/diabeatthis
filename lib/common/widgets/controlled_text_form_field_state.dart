import 'package:flutter/material.dart';

import 'controlled_text_form_field.dart';

class ControlledTextFormFieldState extends State<ControlledTextFormField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant ControlledTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      // Updating a controller notifies the enclosing Form, so wait until build ends.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _controller.text == widget.value) return;
        _controller.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSaved: widget.onSaved,
      validator: widget.validator,
      decoration: widget.decoration,
      maxLength: widget.maxLength,
      textInputAction: widget.textInputAction,
    );
  }
}

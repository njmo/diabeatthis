import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../l10n/language.dart';

/// Returns a trimmed, nonempty name, or null when dismissed.
class EditNameDialog extends HookWidget {
  const EditNameDialog({
    super.key,
    required this.initialName,
    required this.title,
    required this.label,
    required this.requiredMessage,
  });

  final String initialName;
  final String title;
  final String label;
  final String requiredMessage;

  @override
  Widget build(BuildContext context) {
    final input = useTextEditingController(text: initialName);
    final form = useMemoized(GlobalKey<FormState>.new);
    void save() {
      if (form.currentState!.validate()) {
        Navigator.pop(context, input.text.trim());
      }
    }

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          controller: input,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: label),
          validator: (value) =>
              value == null || value.trim().isEmpty ? requiredMessage : null,
          onFieldSubmitted: (_) => save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.lang.commonCancel),
        ),
        FilledButton(onPressed: save, child: Text(context.lang.commonSave)),
      ],
    );
  }
}

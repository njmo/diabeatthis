import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../l10n/language.dart';
import 'profile_photo_picker.dart';

class ProfileNameField extends HookWidget {
  const ProfileNameField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.onChanged,
    this.onSaved,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;

  @override
  Widget build(BuildContext context) {
    final localController = useTextEditingController(text: initialValue);
    final nameController = controller ?? localController;
    useListenable(nameController);
    return Row(
      children: [
        ProfilePhotoPicker(name: nameController.text, enabled: enabled),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: nameController,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: label,
              hintText: context.lang.settingsNameHint,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: onChanged,
            onSaved: onSaved,
          ),
        ),
      ],
    );
  }
}

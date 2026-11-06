import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../auth/google_authentication_providers.dart';
import '../l10n/language.dart';
import 'profile_photo_picker.dart';

class ProfileNameField extends HookConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(googleAccountProvider).asData?.value;
    final localController = useTextEditingController(text: initialValue);
    final nameController = controller ?? localController;
    useListenable(nameController);
    final googleController = useTextEditingController(
      text: account?.label,
      keys: [account?.uid, account?.label],
    );
    return Row(
      children: [
        ProfilePhotoPicker(name: nameController.text, enabled: enabled),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            key: ValueKey(
              account == null
                  ? 'local'
                  : 'google:${account.uid}:${account.label}',
            ),
            controller: account == null ? nameController : googleController,
            enabled: enabled && account == null,
            decoration: InputDecoration(
              labelText: label,
              hintText: context.lang.settingsNameHint,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: onChanged,
            onSaved: (_) => onSaved?.call(nameController.text),
          ),
        ),
      ],
    );
  }
}

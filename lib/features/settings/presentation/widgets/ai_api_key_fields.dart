import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class AiApiKeyFields extends StatelessWidget {
  const AiApiKeyFields({
    super.key,
    required this.controller,
    required this.hasSavedKey,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    this.errorText,
  });

  final TextEditingController controller;
  final bool? hasSavedKey;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.lang.settingsAiOpenAiDescription),
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        enabled: enabled,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: context.lang.settingsAiApiKeyLabel,
          helperText: hasSavedKey == true
              ? context.lang.settingsAiApiKeySaved
              : context.lang.settingsAiApiKeyHint,
          helperMaxLines: 3,
          errorText: errorText,
        ),
        onChanged: (_) => onChanged(),
      ),
      if (hasSavedKey == null) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (hasSavedKey == true)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.delete_outline),
            label: Text(context.lang.settingsAiRemoveApiKey),
          ),
        ),
    ],
  );
}

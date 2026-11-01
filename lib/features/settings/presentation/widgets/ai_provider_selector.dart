import 'package:flutter/material.dart';

import '../../../../common/ai/ai_provider_kind.dart';
import '../../../../common/l10n/language.dart';

class AiProviderSelector extends StatelessWidget {
  const AiProviderSelector({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final AiProviderKind value;
  final bool enabled;
  final ValueChanged<AiProviderKind> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: context.lang.settingsAiProviderLabel,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<AiProviderKind>(
        value: value,
        isExpanded: true,
        isDense: true,
        items: [
          DropdownMenuItem(
            value: AiProviderKind.firebase,
            child: Text(context.lang.settingsAiFirebaseProvider),
          ),
          DropdownMenuItem(
            value: AiProviderKind.openAi,
            child: Text(context.lang.settingsAiOpenAiProvider),
          ),
          DropdownMenuItem(
            value: AiProviderKind.chatGpt,
            child: Text(context.lang.settingsAiChatGptProvider),
          ),
        ],
        onChanged: enabled
            ? (provider) {
                if (provider != null) onChanged(provider);
              }
            : null,
      ),
    ),
  );
}

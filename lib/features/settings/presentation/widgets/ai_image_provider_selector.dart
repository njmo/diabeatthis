import 'package:flutter/material.dart';

import '../../../../common/ai/ai_provider_capabilities.dart';
import '../../../../common/ai/ai_provider_kind.dart';
import '../../../../common/l10n/language.dart';

enum AiImageProviderChoice { disabled, inherit, firebase, openAi, chatGpt }

class AiImageProviderSelector extends StatelessWidget {
  const AiImageProviderSelector({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.mainProvider = AiProviderKind.firebase,
    this.generationEnabled = true,
    this.onDisable,
  });
  final AiProviderKind? value;
  final AiProviderKind mainProvider;
  final bool generationEnabled;
  final VoidCallback? onDisable;
  final bool enabled;
  final ValueChanged<AiProviderKind?> onChanged;

  @override
  Widget build(
    BuildContext context,
  ) => DropdownButtonFormField<AiImageProviderChoice>(
    key: ValueKey((value, mainProvider, generationEnabled)),
    initialValue:
        !generationEnabled || !supportsAiImageGeneration(value ?? mainProvider)
        ? AiImageProviderChoice.disabled
        : value == null
        ? AiImageProviderChoice.inherit
        : AiImageProviderChoice.values.byName(value!.name),
    isExpanded: true,
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      labelText: context.lang.settingsAiImageProviderLabel,
    ),
    items: [
      DropdownMenuItem(
        value: AiImageProviderChoice.disabled,
        child: Text(context.lang.settingsAiImagesDisabled),
      ),
      if (supportsAiImageGeneration(mainProvider))
        DropdownMenuItem(
          value: AiImageProviderChoice.inherit,
          child: Text(context.lang.settingsAiImageProviderInherit),
        ),
      for (final provider in AiProviderKind.values.where(
        supportsAiImageGeneration,
      ))
        DropdownMenuItem(
          value: AiImageProviderChoice.values.byName(provider.name),
          child: Text(
            provider == AiProviderKind.firebase
                ? context.lang.settingsAiFirebaseProvider
                : context.lang.settingsAiOpenAiProvider,
          ),
        ),
    ],
    onChanged: enabled
        ? (value) => value == AiImageProviderChoice.disabled
              ? onDisable?.call()
              : onChanged(
                  value == AiImageProviderChoice.inherit
                      ? null
                      : AiProviderKind.values.byName(value!.name),
                )
        : null,
  );
}

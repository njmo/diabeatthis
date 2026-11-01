import 'package:flutter/material.dart';

import '../../../../common/ai/ai_model_option.dart';
import '../../../../common/l10n/language.dart';

class AiChatGptModelSelector extends StatelessWidget {
  const AiChatGptModelSelector({
    super.key,
    required this.models,
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onChanged,
    required this.onReload,
  });

  final List<AiModelOption>? models;
  final String value;
  final bool enabled;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LinearProgressIndicator();
    final options = models;
    if (options == null || options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.lang.settingsAiModelsUnavailable),
          TextButton.icon(
            onPressed: enabled ? onReload : null,
            icon: const Icon(Icons.refresh),
            label: Text(context.lang.settingsAiReloadModels),
          ),
        ],
      );
    }
    final selectedExists = options.any((option) => option.id == value);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: context.lang.settingsAiModelLabel,
        errorText: selectedExists
            ? null
            : context.lang.settingsAiChooseAvailableModel,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedExists ? value : null,
          isExpanded: true,
          isDense: true,
          items: [
            for (final model in options)
              DropdownMenuItem(value: model.id, child: Text(model.label)),
          ],
          onChanged: enabled
              ? (model) {
                  if (model != null) onChanged(model);
                }
              : null,
        ),
      ),
    );
  }
}

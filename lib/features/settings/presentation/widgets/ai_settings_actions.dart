import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class AiSettingsActions extends StatelessWidget {
  const AiSettingsActions({
    super.key,
    required this.busy,
    required this.enabled,
    required this.onSave,
    required this.onTest,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onSave;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.lang.settingsAiTestDescription,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: enabled && !busy ? onSave : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(context.lang.settingsAiSave),
          ),
          OutlinedButton.icon(
            onPressed: enabled && !busy ? onTest : null,
            icon: const Icon(Icons.network_check),
            label: Text(context.lang.settingsAiTest),
          ),
        ],
      ),
      if (busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
    ],
  );
}

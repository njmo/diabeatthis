import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class AiChatGptConnection extends StatelessWidget {
  const AiChatGptConnection({
    super.key,
    required this.connected,
    required this.enabled,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool? connected;
  final bool enabled;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.lang.settingsAiChatGptDescription),
      const SizedBox(height: 12),
      if (connected == null)
        const LinearProgressIndicator()
      else ...[
        Text(
          connected!
              ? context.lang.settingsAiChatGptConnected
              : context.lang.settingsAiChatGptDisconnected,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: connected!
              ? OutlinedButton.icon(
                  onPressed: enabled ? onDisconnect : null,
                  icon: const Icon(Icons.logout),
                  label: Text(context.lang.settingsAiChatGptDisconnect),
                )
              : OutlinedButton.icon(
                  onPressed: enabled ? onConnect : null,
                  icon: const Icon(Icons.login),
                  label: Text(context.lang.settingsAiChatGptConnect),
                ),
        ),
      ],
    ],
  );
}

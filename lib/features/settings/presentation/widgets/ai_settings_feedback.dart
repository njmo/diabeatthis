import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/ai/auth/chat_gpt_auth_exception.dart';
import '../../../../common/analysis/ai_request_error_message.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../../core/llm/local_llm_client.dart';

enum AiSettingsFeedbackKind {
  saved,
  tested,
  connected,
  disconnected,
  keyRemoved,
}

class AiSettingsFeedback extends StatelessWidget {
  const AiSettingsFeedback({super.key, this.success, this.error});

  final AiSettingsFeedbackKind? success;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final message = failure != null
        ? failure is ChatGptRevocationUnconfirmedException
              ? context.lang.settingsAiChatGptDisconnectedLocally
              : failure is LlmRequestException || failure is TimeoutException
              ? aiRequestErrorMessage(context.lang, failure)
              : context.lang.settingsAiActionFailed
        : switch (success) {
            AiSettingsFeedbackKind.saved => context.lang.settingsAiSaved,
            AiSettingsFeedbackKind.tested => context.lang.settingsAiTestPassed,
            AiSettingsFeedbackKind.connected =>
              context.lang.settingsAiChatGptConnected,
            AiSettingsFeedbackKind.disconnected =>
              context.lang.settingsAiChatGptDisconnected,
            AiSettingsFeedbackKind.keyRemoved =>
              context.lang.settingsAiApiKeyRemoved,
            null => null,
          };
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: StatusInfoCard(
        icon: failure == null
            ? Icons.check_circle_outline
            : Icons.error_outline,
        title: message,
      ),
    );
  }
}

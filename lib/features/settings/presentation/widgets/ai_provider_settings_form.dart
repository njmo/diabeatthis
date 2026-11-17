import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/ai/ai_configuration.dart';
import '../../../../common/ai/ai_model_option.dart';
import '../../../../common/ai/ai_provider_capabilities.dart';
import '../../../../common/ai/ai_provider_kind.dart';
import '../../../../common/ai/ai_settings_controller.dart';
import '../../../../common/forms/form_submission_controller.dart';
import '../../../../common/l10n/language.dart';
import 'ai_api_key_fields.dart';
import 'ai_author_funded_notice.dart';
import 'ai_chat_gpt_connection.dart';
import 'ai_chat_gpt_model_selector.dart';
import 'ai_image_provider_selector.dart';
import 'ai_model_field.dart';
import 'ai_provider_selector.dart';
import 'ai_settings_actions.dart';
import 'ai_settings_feedback.dart';

class AiProviderSettingsForm extends HookConsumerWidget {
  const AiProviderSettingsForm({
    super.key,
    required this.initialConfiguration,
    this.onChanged,
    this.onSaved,
    this.submissionController,
    this.showActions = true,
    this.hideFirebaseModel = true,
    this.connectChatGptOnSelection = false,
  });

  final AiConfiguration initialConfiguration;
  final VoidCallback? onChanged;
  final VoidCallback? onSaved;
  final FormSubmissionController? submissionController;
  final bool showActions;
  final bool hideFirebaseModel;
  final bool connectChatGptOnSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initialConfiguration.normalizeImageGeneration());
    final apiKey = useTextEditingController();
    useListenable(apiKey);
    final validationRequested = useState(false);
    final busy = useState(false);
    final hasSavedKey = useState<bool?>(null);
    final connected = useState<bool?>(null);
    final credentialRevision = useState(0);
    final models = useState<List<AiModelOption>?>(null);
    final modelsLoading = useState(false);
    final error = useState<Object?>(null);
    final success = useState<AiSettingsFeedbackKind?>(null);
    final controller = ref.read(aiSettingsControllerProvider.notifier);
    final provider = draft.value.provider;

    void clearFeedback() {
      onChanged?.call();
      error.value = null;
      success.value = null;
    }

    useEffect(
      () {
        var active = true;
        Future<void> loadConnection() async {
          try {
            if (draft.value.requiresApiKey) {
              hasSavedKey.value = null;
              final saved = await controller.hasApiKey();
              if (active) hasSavedKey.value = saved;
            }
            if (provider == AiProviderKind.chatGpt) {
              connected.value = null;
              models.value = null;
              modelsLoading.value = false;
              final signedIn = await controller.isChatGptConnected();
              if (!active) return;
              connected.value = signedIn;
              if (signedIn) {
                modelsLoading.value = true;
                final available = await controller.chatGptModels();
                if (!active) return;
                models.value = available;
                if (draft.value.chatGptModel.isEmpty && available.isNotEmpty) {
                  draft.value = draft.value.copyWith(
                    chatGptModel: available.first.id,
                  );
                }
              }
            }
          } catch (failure) {
            if (active) {
              error.value = failure;
              if (provider == AiProviderKind.openAi) hasSavedKey.value = false;
              if (provider == AiProviderKind.chatGpt) {
                var stillConnected = false;
                try {
                  stillConnected = await controller.isChatGptConnected();
                } catch (_) {
                  // Keep the original failure and offer sign-in when status cannot be read.
                }
                if (active) connected.value = stillConnected;
              }
            }
          } finally {
            if (active) modelsLoading.value = false;
          }
        }

        loadConnection();
        return () {
          active = false;
        };
      },
      [
        provider,
        draft.value.effectiveImageProvider,
        draft.value.imageGenerationEnabled,
        credentialRevision.value,
      ],
    );

    Future<void> runAction(
      Future<void> Function() action,
      AiSettingsFeedbackKind result, {
      bool refreshCredentials = false,
    }) async {
      clearFeedback();
      busy.value = true;
      try {
        await action();
        if (context.mounted) success.value = result;
      } catch (failure) {
        if (context.mounted) error.value = failure;
      } finally {
        if (context.mounted) {
          busy.value = false;
          if (refreshCredentials) credentialRevision.value++;
        }
      }
    }

    void updateModel(String value) {
      clearFeedback();
      draft.value = switch (provider) {
        AiProviderKind.firebase => draft.value.copyWith(firebaseModel: value),
        AiProviderKind.openAi => draft.value.copyWith(openAiModel: value),
        AiProviderKind.chatGpt => draft.value.copyWith(chatGptModel: value),
      };
    }

    final ready = switch (provider) {
      AiProviderKind.firebase => true,
      AiProviderKind.openAi => hasSavedKey.value != null,
      AiProviderKind.chatGpt =>
        connected.value == true &&
            !modelsLoading.value &&
            (models.value?.any(
                  (model) => model.id == draft.value.chatGptModel,
                ) ??
                false),
    };

    final modelValid = draft.value.model.trim().isNotEmpty;
    final keyValid =
        !draft.value.requiresApiKey ||
        apiKey.text.trim().isNotEmpty ||
        hasSavedKey.value == true;

    bool validate() {
      validationRequested.value = true;
      return draft.value.model.trim().isNotEmpty &&
          (!draft.value.requiresApiKey ||
              apiKey.text.trim().isNotEmpty ||
              hasSavedKey.value == true);
    }

    Future<bool> submitForStep() async {
      if (busy.value || !ready || !validate()) return false;
      error.value = null;
      success.value = null;
      busy.value = true;
      final configuration = draft.value;
      final key = configuration.requiresApiKey ? apiKey.text.trim() : null;
      try {
        await controller.testConnection(configuration, apiKey: key);
        if (!context.mounted) return false;
        await controller.save(configuration, apiKey: key);
        if (!context.mounted) return false;
        apiKey.clear();
        onSaved?.call();
        return true;
      } catch (failure) {
        if (context.mounted) error.value = failure;
        return false;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    useEffect(
      () {
        final submission = submissionController;
        submission?.attach(
          submitForStep,
          ready: ready && !busy.value && modelValid && keyValid,
        );
        return () => submission?.detach(submitForStep);
      },
      [
        submissionController,
        draft.value,
        ready,
        busy.value,
        modelValid,
        keyValid,
        apiKey.text,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiProviderSelector(
          value: provider,
          enabled: !busy.value,
          onChanged: (value) {
            clearFeedback();
            validationRequested.value = false;
            draft.value = draft.value
                .copyWith(provider: value)
                .normalizeImageGeneration();
            if (value == AiProviderKind.chatGpt && connectChatGptOnSelection) {
              runAction(
                controller.connectChatGpt,
                AiSettingsFeedbackKind.verified,
                refreshCredentials: true,
              );
            }
          },
        ),
        const SizedBox(height: 12),
        if (provider == AiProviderKind.firebase)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.lang.settingsAiFirebaseDescription),
              const SizedBox(height: 8),
              const AiAuthorFundedNotice(),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Model: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      draft.value.firebaseModel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (draft.value.requiresApiKey)
          AiApiKeyFields(
            controller: apiKey,
            hasSavedKey: hasSavedKey.value,
            enabled: !busy.value,
            onChanged: clearFeedback,
            errorText: validationRequested.value && !keyValid
                ? context.lang.settingsAiApiKeyRequired
                : null,
            onRemove: () => runAction(
              () async {
                await controller.deleteApiKey();
                if (context.mounted) apiKey.clear();
              },
              AiSettingsFeedbackKind.keyRemoved,
              refreshCredentials: true,
            ),
          ),
        if (provider == AiProviderKind.chatGpt)
          AiChatGptConnection(
            connected: connected.value,
            enabled: !busy.value,
            onConnect: () => runAction(
              controller.connectChatGpt,
              connectChatGptOnSelection
                  ? AiSettingsFeedbackKind.verified
                  : AiSettingsFeedbackKind.connected,
              refreshCredentials: true,
            ),
            onDisconnect: () => runAction(
              controller.disconnectChatGpt,
              AiSettingsFeedbackKind.disconnected,
              refreshCredentials: true,
            ),
          ),
        const SizedBox(height: 12),
        if (provider == AiProviderKind.chatGpt && connected.value == true)
          AiChatGptModelSelector(
            models: models.value,
            value: draft.value.chatGptModel,
            enabled: !busy.value,
            loading: modelsLoading.value,
            onChanged: updateModel,
            onReload: () {
              clearFeedback();
              credentialRevision.value++;
            },
          ),
        if (provider != AiProviderKind.chatGpt &&
            provider != AiProviderKind.firebase)
          AiModelField(
            key: ValueKey(provider),
            value: draft.value.model,
            enabled: !busy.value,
            errorText: validationRequested.value && !modelValid
                ? context.lang.settingsAiModelRequired
                : null,
            onChanged: updateModel,
          ),
        const SizedBox(height: 12),
        Text(
          context.lang.settingsAiImageGenerationNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        AiImageProviderSelector(
          value: draft.value.imageProvider,
          mainProvider: provider,
          generationEnabled: draft.value.imageGenerationEnabled,
          onDisable: () {
            clearFeedback();
            draft.value = draft.value.copyWith(imageGenerationEnabled: false);
          },
          enabled: !busy.value,
          onChanged: (value) {
            clearFeedback();
            draft.value = draft.value.copyWith(
              imageProvider: value,
              imageGenerationEnabled: true,
              inheritImageProvider: value == null,
            );
          },
        ),
        if (!supportsAiImageGeneration(draft.value.effectiveImageProvider)) ...[
          const SizedBox(height: 8),
          Text(
            context.lang.settingsAiImagesAlternative,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        if (showActions)
          AiSettingsActions(
            busy: busy.value,
            enabled: ready,
            onSave: () {
              FocusScope.of(context).unfocus();
              if (!validate()) return;
              runAction(
                () async {
                  await controller.save(
                    draft.value,
                    apiKey: draft.value.requiresApiKey
                        ? apiKey.text.trim()
                        : null,
                  );
                  if (context.mounted) {
                    apiKey.clear();
                    onSaved?.call();
                  }
                },
                AiSettingsFeedbackKind.saved,
                refreshCredentials: true,
              );
            },
            onTest: () {
              FocusScope.of(context).unfocus();
              if (!validate()) return;
              runAction(
                () => controller.testConnection(
                  draft.value,
                  apiKey: draft.value.requiresApiKey
                      ? apiKey.text.trim()
                      : null,
                ),
                AiSettingsFeedbackKind.tested,
              );
            },
          ),
        AiSettingsFeedback(success: success.value, error: error.value),
      ],
    );
  }
}

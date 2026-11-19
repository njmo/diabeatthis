import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/language.dart';
import '../application/family_chat_settings_runtime.dart';
import '../domain/family_chat_preferences.dart';
import 'family_chat_configuration.dart';

class FamilyChatSettingsSection extends ConsumerStatefulWidget {
  const FamilyChatSettingsSection({super.key, this.showAccount = true});
  final bool showAccount;
  @override
  ConsumerState<FamilyChatSettingsSection> createState() =>
      _FamilyChatSettingsSectionState();
}

class _FamilyChatSettingsSectionState
    extends ConsumerState<FamilyChatSettingsSection> {
  bool saving = false;
  Future<void> save(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.familyChatSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final runtime = ref.watch(familyChatSettingsRuntimeProvider);
    if (runtime == null) return Text(context.lang.familyChatJoinRequired);
    return ListenableBuilder(
      listenable: runtime,
      builder: (context, _) {
        final lang = context.lang, controller = runtime.controller;
        final state = controller.state, config = controller.confirmed;
        if (config == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                controller.denied
                    ? lang.familyChatJoinRequired
                    : lang.familyChatLoadingSettings,
              ),
              TextButton.icon(
                onPressed: () => save(runtime.pump),
                icon: const Icon(Icons.refresh),
                label: Text(lang.familyChatRefreshSettings),
              ),
            ],
          );
        }
        final account = state['account'] as Map?,
            policy = state['policy'] as Map?;
        final enabled =
            account?['changes']?['accountEnabled'] as bool? ??
            config['account']['enabled'] as bool;
        ChatRetention retention(Object? value) =>
            ChatRetention.values.where((v) => v.name == value).firstOrNull ??
            ChatRetention.week;
        final actualRetention = retention(config['policy']['retention']);
        final selectedRetention = retention(
          policy?['changes']?['retention'] ?? actualRetention.name,
        );
        String period(ChatRetention value) => switch (value) {
          ChatRetention.day => lang.familyChatRetentionDay,
          ChatRetention.week => lang.familyChatRetentionWeek,
          ChatRetention.month => lang.familyChatRetentionMonth,
          ChatRetention.unlimited => lang.familyChatRetentionUnlimited,
        };
        final canManage = config['canManage'] == true;
        final pendingOff =
            account?['changes']?['accountEnabled'] == false ||
            policy?['legacyOff'] == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FamilyChatConfiguration(
              showAccount: widget.showAccount,
              cardLayout: true,
              accountTitle: lang.familyChatAccountTitle,
              value: FamilyChatPreferences(
                enabled: enabled,
                retention: selectedRetention,
              ),
              showRetentionWhenDisabled: true,
              canEnable: controller.canRequestEnable,
              canChangeRetention: canManage && policy == null,
              onChanged: saving || !controller.initialized
                  ? null
                  : (value) {
                      if (value.enabled != enabled) {
                        save(() => controller.setAccountEnabled(value.enabled));
                      } else if (value.retention != selectedRetention) {
                        save(
                          () => controller.setFamilyPolicy(
                            retention: value.retention,
                          ),
                        );
                      }
                    },
            ),
            const SizedBox(height: 6),
            Text(
              lang.familyChatSharedRetention,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (pendingOff) Text(lang.familyChatPendingOff),
            if (!pendingOff && (account != null || policy != null))
              Text(lang.familyChatPendingUpdate),
            for (final kind in ['account', 'policy'])
              if (state[kind]?['conflict'] != null) ...[
                Text(lang.familyChatConflict),
                if (kind == 'policy')
                  Text(
                    lang.familyChatCurrentRetention(period(actualRetention)),
                  ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () => save(
                          () =>
                              kind == 'policy' &&
                                  state[kind]['conflict'] == 'scope'
                              ? controller.discardPolicyConflict()
                              : controller.retryPending(kind),
                        ),
                  child: Text(
                    kind == 'policy' && state[kind]['conflict'] == 'scope'
                        ? lang.familyChatDiscardSetting
                        : lang.familyChatRetrySetting,
                  ),
                ),
              ],
            if (runtime.cachedOnly) Text(lang.familyChatOfflineHistory),
            if (controller.localAllowed &&
                !controller.readyForRuntime &&
                controller.canRequestEnable)
              TextButton(
                onPressed: saving
                    ? null
                    : () => save(() => controller.setAccountEnabled(true)),
                child: Text(lang.familyChatReenableHere),
              ),
            if (controller.error != null || runtime.cachedOnly)
              TextButton.icon(
                onPressed: saving ? null : () => save(runtime.pump),
                icon: const Icon(Icons.refresh),
                label: Text(lang.familyChatRefreshSettings),
              ),
          ],
        );
      },
    );
  }
}

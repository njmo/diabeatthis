import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/notifications/providers/notification_retry_preferences.dart';
import 'notification_retry_switch.dart';
import 'settings_section_card.dart';

class NotificationRetrySettingsSection extends HookConsumerWidget {
  const NotificationRetrySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(notificationRetriesEnabledProvider);
    final saving = useState(false);
    return SettingsSectionCard(
      title: context.lang.notificationSettingsTitle,
      icon: Icons.notifications_outlined,
      children: [
        preference.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(context.lang.notificationRetrySaveError),
          data: (enabled) => NotificationRetrySwitch(
            value: enabled,
            onChanged: saving.value
                ? null
                : (value) async {
                    saving.value = true;
                    try {
                      await saveNotificationRetriesEnabled(ref, value);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.lang.notificationRetrySaveError,
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) saving.value = false;
                    }
                  },
          ),
        ),
      ],
    );
  }
}

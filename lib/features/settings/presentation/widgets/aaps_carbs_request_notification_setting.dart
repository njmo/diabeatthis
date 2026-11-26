import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/providers/aaps_carbs_request_notification_preferences.dart';
import '../../../../foreground/event/internal/aaps_carbs_request_notifications_changed.dart';

class AapsCarbsRequestNotificationSetting extends HookConsumerWidget {
  const AapsCarbsRequestNotificationSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(aapsCarbsRequestNotificationsEnabledProvider);
    final saving = useState(false);
    return preference.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) =>
          Text(context.lang.notificationAapsCarbsRequestSettingSaveError),
      data: (enabled) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(context.lang.notificationAapsCarbsRequestSettingTitle),
        subtitle: Text(
          context.lang.notificationAapsCarbsRequestSettingDescription,
        ),
        value: enabled,
        onChanged: saving.value
            ? null
            : (value) async {
                saving.value = true;
                try {
                  await saveAapsCarbsRequestNotificationsEnabled(ref, value);
                  _wakeMonitor(ref);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context
                              .lang
                              .notificationAapsCarbsRequestSettingSaveError,
                        ),
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) saving.value = false;
                }
              },
      ),
    );
  }

  void _wakeMonitor(WidgetRef ref) {
    try {
      ref
          .read(appEventRouterProvider)
          .send(const AapsCarbsRequestNotificationsChanged());
    } catch (error) {
      // The monitor still reads the setting at its next check.
      Log.w('AapsCarbsRequest', 'Could not wake the monitor: $error');
    }
  }
}

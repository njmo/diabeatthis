import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const notificationRetriesEnabledKey = 'notification_retries_enabled';

final notificationRetriesEnabledProvider = FutureProvider<bool>(
  (ref) => readNotificationRetriesEnabled(),
);

Future<bool> readNotificationRetriesEnabled() async =>
    await SharedPreferencesAsync().getBool(notificationRetriesEnabledKey) ??
    true;

Future<void> saveNotificationRetriesEnabled(WidgetRef ref, bool enabled) async {
  await SharedPreferencesAsync().setBool(
    notificationRetriesEnabledKey,
    enabled,
  );
  if (ref.context.mounted) ref.invalidate(notificationRetriesEnabledProvider);
}

Future<bool> configureNotificationRetries(
  bool? selection,
  Future<bool> Function() apply,
) async {
  if (selection == null) return apply();
  final prefs = SharedPreferencesAsync();
  final previous = await prefs.getBool(notificationRetriesEnabledKey);
  await prefs.setBool(notificationRetriesEnabledKey, selection);
  var saved = false;
  try {
    saved = await apply();
    return saved;
  } finally {
    if (!saved &&
        await prefs.getBool(notificationRetriesEnabledKey) == selection) {
      if (previous == null) {
        await prefs.remove(notificationRetriesEnabledKey);
      } else {
        await prefs.setBool(notificationRetriesEnabledKey, previous);
      }
    }
  }
}

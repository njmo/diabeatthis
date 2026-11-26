import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const aapsCarbsRequestNotificationsEnabledKey =
    'aaps_carbs_request_notifications_enabled';

final aapsCarbsRequestNotificationsEnabledProvider = FutureProvider<bool>(
  (ref) => readAapsCarbsRequestNotificationsEnabled(),
);

/// Read by the foreground monitor; overridable in tests.
final aapsCarbsRequestNotificationsEnabledReaderProvider =
    Provider<Future<bool> Function()>(
      (ref) => readAapsCarbsRequestNotificationsEnabled,
    );

Future<bool> readAapsCarbsRequestNotificationsEnabled() async =>
    await SharedPreferencesAsync().getBool(
      aapsCarbsRequestNotificationsEnabledKey,
    ) ??
    true;

Future<void> saveAapsCarbsRequestNotificationsEnabled(
  WidgetRef ref,
  bool enabled,
) async {
  await SharedPreferencesAsync().setBool(
    aapsCarbsRequestNotificationsEnabledKey,
    enabled,
  );
  if (ref.context.mounted) {
    ref.invalidate(aapsCarbsRequestNotificationsEnabledProvider);
  }
}

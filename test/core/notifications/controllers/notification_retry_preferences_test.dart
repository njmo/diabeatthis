import 'package:diabeatthis/core/notifications/providers/notification_retry_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'the default is enabled and setup commits only a successful choice',
    () async {
      expect(await readNotificationRetriesEnabled(), isTrue);

      expect(
        await configureNotificationRetries(false, () async => false),
        isFalse,
      );
      expect(await readNotificationRetriesEnabled(), isTrue);

      expect(
        await configureNotificationRetries(false, () async => true),
        isTrue,
      );
      expect(await readNotificationRetriesEnabled(), isFalse);
    },
  );
}

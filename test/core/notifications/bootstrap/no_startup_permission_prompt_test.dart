import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/foreground/bootstrap/foreground_plugin_init.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SilentInitializationNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected platform call during initialization: ${invocation.memberName}',
  );
  InitializationSettings? received;
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    received = settings;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'notification startup initializes without requesting system permissions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final plugin = SilentInitializationNotificationsPlugin();
      await LocalNotificationsController(plugin).init();
      expect(plugin.received!.iOS!.requestAlertPermission, isFalse);
      expect(plugin.received!.iOS!.requestBadgePermission, isFalse);
      expect(plugin.received!.iOS!.requestSoundPermission, isFalse);
    },
  );
  test(
    'foreground initialization does not open permission platform APIs',
    () async {
      await initForegroundPlugin();
    },
  );
}

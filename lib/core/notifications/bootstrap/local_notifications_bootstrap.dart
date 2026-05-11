import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../definitions/notification_definition_catalog_impl.dart';
import '../handlers/notification_response_handler.dart';
import '../mappers/darwin_notification_category_mapper.dart';

bool _timeZonesInitialized = false;

void ensureTimeZonesInitialized() {
  if (_timeZonesInitialized) {
    return;
  }

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
  _timeZonesInitialized = true;
}

Future<void> init(FlutterLocalNotificationsPlugin plugin) async {
  ensureTimeZonesInitialized();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  final iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    notificationCategories: DarwinNotificationCategoryMapper().mapDefinitions(
      NotificationDefinitionCatalogImpl().all,
    ),
  );

  final initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await plugin.initialize(
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
    settings: initSettings,
  );
}

Future<void> requestPermissions(FlutterLocalNotificationsPlugin plugin) async {
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await android?.requestNotificationsPermission();

  final canExact = await android?.canScheduleExactNotifications() ?? true;
  if (!canExact) {
    await android?.requestExactAlarmsPermission();
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../handlers/notification_response_handler.dart';

Future<void> init(FlutterLocalNotificationsPlugin plugin) async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  final iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    notificationCategories: [
      DarwinNotificationCategory(
        'meal_category',
        actions: [
          DarwinNotificationAction.plain('meal_yes', 'Zaczynam jeść ✅'),
          DarwinNotificationAction.plain('meal_not_yet', 'Jeszcze nie'),
        ],
      ),
    ],
  );

  final initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await plugin.initialize(
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
    onDidReceiveBackgroundNotificationResponse, settings: initSettings,
  );
}

Future<void> requestPermissions(FlutterLocalNotificationsPlugin plugin) async {
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await android?.requestNotificationsPermission();

  final canExact = await android?.canScheduleExactNotifications() ?? true;
  if (!canExact) {
    await android?.requestExactAlarmsPermission();
  }
}
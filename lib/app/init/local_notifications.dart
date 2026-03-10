import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../handlers/notification_response_handler.dart';
import '../router/providers/flutter_local_notifications_plugin_provider.dart';

Future<void> init(Ref ref) async {
  _notificationsInit(ref);
}

Future<void> _notificationsInit(Ref ref) async {
  final plugin = ref.read(flutterLocalNotificationsPluginProvider);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await plugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
    onDidReceiveBackgroundNotificationResponse,
  );

  // catch app launch notification.
  final launch = await plugin.getNotificationAppLaunchDetails();
  final resp = launch?.notificationResponse;
  if (resp != null) {
    onDidReceiveNotificationResponse(resp);
  }

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
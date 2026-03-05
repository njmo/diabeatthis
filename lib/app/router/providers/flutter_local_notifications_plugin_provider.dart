import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../handlers/notification_response_handler.dart';

part 'flutter_local_notifications_plugin_provider.g.dart';

@Riverpod(keepAlive: true)
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin(Ref ref)
{
  final flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  return flutterLocalNotificationsPlugin;
}

@Riverpod(keepAlive: true)
Future<void> notificationsInit(Ref ref) async {
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

  await plugin.initialize(settings: initSettings);

  // catch app launch notification.
  final launch = await plugin.getNotificationAppLaunchDetails();
  final resp = launch?.notificationResponse;
  if (resp != null) {
    onDidReceiveNotificationResponse(resp);
  }

  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await android?.requestNotificationsPermission();

  final canExact = await android?.canScheduleExactNotifications() ?? true;
  if (!canExact) {
    await android?.requestExactAlarmsPermission();
  }
}
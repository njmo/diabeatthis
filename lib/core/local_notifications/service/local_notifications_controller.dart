import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart';
import '../bootstrap/local_notifications_bootstrap.dart' as bootstrap;

import '../handlers/notification_response_handler.dart';

class LocalNotificationsController {
  LocalNotificationsController(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    await bootstrap.init(_plugin);
    await bootstrap.requestPermissions(_plugin);

    await _handleLaunchNotification();
  }

  Future<void> _handleLaunchNotification() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;

    if (response != null) {
      onDidReceiveNotificationResponse(response);
    }
  }

  Future<List<PendingNotificationRequest>> show({
    required int id,
    required String title,
    required String body,
    required TZDateTime when,
    required NotificationDetails details,
    required int notificationId,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
        id: notificationId,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
        payload: payload
    );

    return await _plugin.pendingNotificationRequests();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
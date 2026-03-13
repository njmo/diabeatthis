import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../application/notifications_controller.dart';
import '../bootstrap/local_notifications_bootstrap.dart' as bootstrap;

import '../domain/models/hash_notification_id_factory.dart';
import '../domain/models/notification_event.dart';
import '../handlers/notification_response_handler.dart';
import '../mappers/android_notification_details_mapper.dart';
import '../mappers/darwin_notification_details_mapper.dart';

class LocalNotificationsController implements NotificationsController {
  LocalNotificationsController(this._plugin)
    : _idFactory = HashNotificationIdFactory();

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationIdFactory _idFactory;

  @override
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

  @override
  Future<void> show(NotificationEvent event) async {
    final androidDetails = event.toAndroidNotificationDetails();
    final iosDetails = event.toDarwinNotificationDetails();
    final id = _idFactory.create(event.key);
    return _plugin.show(
      id: id,
      title: event.title,
      body: event.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(event.toPayload()),
    );
  }

  @override
  Future<void> schedule(NotificationEvent event, Duration duration) async {
    final androidDetails = event.toAndroidNotificationDetails();
    final iosDetails = event.toDarwinNotificationDetails();
    final id = _idFactory.create(event.key);

    final when = tz.TZDateTime.now(tz.local).add(duration);

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: event.title,
      body: event.body,
      payload: jsonEncode(event.toPayload()),
    );
  }

  @override
  Future<Iterable<int>> get pending async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests.map((r) => r.id);
  }

  @override
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

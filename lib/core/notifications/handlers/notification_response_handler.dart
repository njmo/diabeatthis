import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint(
    'BG RESPONSE: actionId=${response.actionId} data=${response.payload}',
  );

  FlutterForegroundTask.initCommunicationPort();

  Map<String, Object> json;
  try {
    final data = response.payload ?? '{}';
    final action = response.actionId ?? 'empty';

    final dataJson = jsonDecode(data) as Map<String, dynamic>;
    final responseEventType = dataJson['response_event_type'] as String;
    final actionData = dataJson['action_data'] as Map<String, dynamic>;

    json = {
      'external_event': 'notification_event',
      'data': {
        'notification_response_event': responseEventType,
        'data': {
          'action': action,
          ...actionData
        },
      },
    };
  }
  catch (e) {
    debugPrint('Error parsing notification response: $e');
    return;
  }

  debugPrint('Sending data to router: $json');

  FlutterForegroundTask.sendDataToTask(jsonEncode(json));
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint(
    'BG BACKGROUND RESPONSE: actionId=${response.actionId} data=${response.payload}',
  );

  onDidReceiveNotificationResponse(response);
}

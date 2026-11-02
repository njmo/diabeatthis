import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../common/meal/pending_meal_completion_requests.dart';

Future<void> onDidReceiveNotificationResponse(
  NotificationResponse response,
) async {
  debugPrint(
    'BG RESPONSE: actionId=${response.actionId} data=${response.payload}',
  );

  Map<String, Object> json;
  try {
    final data = response.payload ?? '{}';
    final action = response.actionId ?? 'empty';
    final input = response.input;

    final dataJson = jsonDecode(data) as Map<String, dynamic>;
    final responseEventType = dataJson['response_event_type'] as String?;
    if (responseEventType == null || responseEventType.isEmpty) {
      debugPrint('Notification has no foreground response event');
      return;
    }
    final actionData = dataJson['action_data'] as Map<String, dynamic>;
    if (input != null) {
      actionData['input'] = input;
    }

    if (responseEventType == 'finished_eating_response' && action == 'agree') {
      final mealId = actionData['mealId'];
      if (mealId is int) {
        try {
          await const PendingMealCompletionRequests().request(mealId);
        } catch (error) {
          debugPrint('Could not persist meal completion intent: $error');
        }
      }
    }

    json = {
      'external_event': 'notification_event',
      'data': {
        'notification_response_event': responseEventType,
        'data': {'action': action, ...actionData},
      },
    };
  } catch (e) {
    debugPrint('Error parsing notification response: $e');
    return;
  }

  debugPrint('Sending data to router: $json');

  FlutterForegroundTask.sendDataToTask(jsonEncode(json));
}

/// Replays a durable fresh confirmation after the service has finished starting.
void replayFinishedEatingConfirmation(int mealId) {
  FlutterForegroundTask.sendDataToTask(
    jsonEncode({
      'external_event': 'notification_event',
      'data': {
        'notification_response_event': 'finished_eating_response',
        'data': {'action': 'agree', 'mealId': mealId},
      },
    }),
  );
}

@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  debugPrint(
    'BG BACKGROUND RESPONSE: actionId=${response.actionId} data=${response.payload}',
  );

  await onDidReceiveNotificationResponse(response);
}

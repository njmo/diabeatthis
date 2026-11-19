import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../common/family_chat/notifications/family_chat_presenter.dart';
import '../../../common/family_chat/notifications/family_chat_push.dart';
import '../../../common/meal/pending_meal_completion_requests.dart';
import '../../../common/meal_advisor/notifications/meal_decision_notification_intent.dart';
import '../inbox/notification_inbox_store.dart';

/// Payload key carrying the OS notification id, so a response can resolve the
/// matching inbox entry.
const notificationIdPayloadKey = 'notification_id';

Future<void> onDidReceiveNotificationResponse(
  NotificationResponse response,
) async {
  if (familyChatNotificationPayload(response.payload) != null) {
    await _updateInbox(response.payload, response.actionId);
    await handleFamilyChatNotificationResponse(response);
    return;
  }
  final decisionIntent = MealDecisionNotificationIntent.parse(
    response.payload,
    response.actionId,
  );
  if (decisionIntent != null) {
    await MealDecisionNotificationIntentStore().add(decisionIntent);
    return;
  }

  debugPrint(
    'BG RESPONSE: actionId=${response.actionId} data=${response.payload}',
  );

  await _updateInbox(response.payload, response.actionId);
  await dispatchNotificationResponse(
    payload: response.payload,
    actionId: response.actionId,
    input: response.input,
  );
}

Future<void> _updateInbox(String? payload, String? actionId) async {
  try {
    final id =
        (jsonDecode(payload ?? '{}')
            as Map<String, dynamic>)[notificationIdPayloadKey];
    if (id is! int) return;
    final inbox = NotificationInboxStore();
    if (actionId == null || actionId.isEmpty) {
      await inbox.markRead([id]);
    } else {
      await inbox.resolve(id);
    }
  } catch (e) {
    debugPrint('Could not update notification inbox: $e');
  }
}

/// Answers a notification from an in-app banner or the inbox exactly like the
/// matching system notification button. Chat answers are handled in place;
/// [familyChatPresenter] lets their follow-up status reach the user in-app.
Future<void> respondToNotification({
  required String payload,
  required String? actionId,
  String? input,
  AndroidFamilyChatPresenter? familyChatPresenter,
}) async {
  if (familyChatNotificationPayload(payload) != null) {
    await handleFamilyChatNotificationResponse(
      NotificationResponse(
        notificationResponseType: actionId == null
            ? NotificationResponseType.selectedNotification
            : NotificationResponseType.selectedNotificationAction,
        actionId: actionId,
        input: input,
        payload: payload,
      ),
      presenter: familyChatPresenter,
    );
    return;
  }
  if (actionId == null) return;
  await dispatchNotificationResponse(
    payload: payload,
    actionId: actionId,
    input: input,
  );
}

/// Forwards a notification answer to the foreground service. Shared by system
/// notification responses and in-app banner / inbox buttons, so both paths
/// trigger exactly the same handling.
Future<void> dispatchNotificationResponse({
  required String? payload,
  required String? actionId,
  String? input,
}) async {
  Map<String, Object> json;
  try {
    final data = payload ?? '{}';
    final action = actionId ?? 'empty';

    final dataJson = jsonDecode(data) as Map<String, dynamic>;
    final responseEventType = dataJson['response_event_type'] as String?;
    if (responseEventType == null || responseEventType.isEmpty) {
      debugPrint('Notification has no foreground response event');
      return;
    }
    final actionData = Map<String, dynamic>.from(
      dataJson['action_data'] as Map,
    );
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

void notifyFinishedEatingConfirmationDismissed(int mealId) {
  _sendFinishedEatingResponse(mealId, 'confirmation_dismissed');
}

/// Replays a durable fresh confirmation after the service has finished starting.
void replayFinishedEatingConfirmation(int mealId) {
  _sendFinishedEatingResponse(mealId, 'agree');
}

void _sendFinishedEatingResponse(int mealId, String action) {
  FlutterForegroundTask.sendDataToTask(
    jsonEncode({
      'external_event': 'notification_event',
      'data': {
        'notification_response_event': 'finished_eating_response',
        'data': {'action': action, 'mealId': mealId},
      },
    }),
  );
}

@pragma('vm:entry-point')
Future<void> onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  if (familyChatNotificationPayload(response.payload) != null) {
    await _updateInbox(response.payload, response.actionId);
    await handleFamilyChatNotificationResponse(response);
    return;
  }
  debugPrint(
    'BG BACKGROUND RESPONSE: actionId=${response.actionId} data=${response.payload}',
  );

  await onDidReceiveNotificationResponse(response);
}

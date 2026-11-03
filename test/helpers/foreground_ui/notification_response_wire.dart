import 'dart:convert';

import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';

Map<String, dynamic> notificationResponseWire(
  NotificationEvent notification,
  String action, {
  String? input,
}) {
  final payload = notification.toPayload();
  final actionData = Map<String, dynamic>.from(payload['action_data']! as Map);
  final wire = {
    'external_event': 'notification_event',
    'data': {
      'notification_response_event': payload['response_event_type'],
      'data': {
        'action': action,
        ...actionData,
        if (input != null) 'input': input,
      },
    },
  };
  return jsonDecode(jsonEncode(wire)) as Map<String, dynamic>;
}

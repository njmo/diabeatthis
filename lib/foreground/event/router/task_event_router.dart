import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/task_event_payload.dart';
import '../../../core/logger/logger.dart';

class TaskEventRouter with Logging {
  void send(TaskEventPayload payload) {
    try {
      logI("Sending task event payload: $payload");
      final json = jsonEncode(payload.toTaskEventJson());
      FlutterForegroundTask.sendDataToMain(json);
    } catch (e) {
      logE("Error sending task event payload: $e");
    }
  }
}

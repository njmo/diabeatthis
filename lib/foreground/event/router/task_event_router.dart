import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/task_event_payload.dart';

class TaskEventRouter {
  void send(TaskEventPayload payload) {
    final json = jsonEncode(payload.toTaskEventJson());
    FlutterForegroundTask.sendDataToMain(json);
  }
}
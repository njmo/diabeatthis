import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/app_event_payload.dart';

class AppEventRouter {
  void send(AppEventPayload payload) {
    final json = jsonEncode(payload.toAppEventJson());
    FlutterForegroundTask.sendDataToTask(json);
  }
}
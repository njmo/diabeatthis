import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/data/app_event_data.dart';

class AppEventRouter {
  void send(AppEventData payload) {
    final json = jsonEncode(payload.toExternalAppEventJson());
    FlutterForegroundTask.sendDataToTask(json);
  }
}

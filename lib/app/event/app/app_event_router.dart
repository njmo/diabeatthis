import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/data/app_event_data.dart';
import '../../../core/logger/logger.dart';

class AppEventRouter with Logging {
  void send(AppEventData payload) {
    logI("Sending data $payload");
    try {
      final json = jsonEncode(payload.toExternalAppEventJson());
      FlutterForegroundTask.sendDataToTask(json);
    } catch (e) {
      logE("Error sending data $e");
    }
  }
}

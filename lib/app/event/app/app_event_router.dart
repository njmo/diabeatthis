import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/data/app_event_data.dart';
import '../../../core/logger/logger.dart';

class AppEventRouter with Logging {
  void send(AppEventData payload) {
    logI("Sending data $payload");
    try {
      final json = jsonEncode(payload.toExternalAppEventJson());
      // The plugin call is fire-and-forget; keep its asynchronous failure
      // (e.g. no running service) from escaping as an uncaught error.
      runZonedGuarded(
        () => FlutterForegroundTask.sendDataToTask(json),
        (error, _) => logE("Error sending data $error"),
      );
    } catch (e) {
      logE("Error sending data $e");
    }
  }
}

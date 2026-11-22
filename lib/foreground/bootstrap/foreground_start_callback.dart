import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../debug/debug_treatment_foreground.dart';
import '../runtime/task_handler.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(
    MyTaskHandler(
      handleAdditionalEvent: kDebugMode ? handleDebugTreatmentEvent : null,
    ),
  );
}

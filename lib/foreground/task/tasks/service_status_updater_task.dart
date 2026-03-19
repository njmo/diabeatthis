import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/data/app/lifecycle_state_event.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

class ServiceStatusUpdaterTask extends WorkflowTask {
  @override
  Future<void> run(RuntimeContext context) async {
    while(true) {
      final event = await context.waitForEvent<LifecycleStateEventChanged>();

      await FlutterForegroundTask.updateService(
        notificationTitle:
        'Monitoring aktywny ${AppLifecycleState.values[event.state]}',
        notificationText: 'Ostatna zmiana: ${DateTime.now()}',
      );
    }
  }
}

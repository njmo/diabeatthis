import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../core/logger/logger.dart';
import '../bootstrap/foreground_plugin_init.dart';
import '../bootstrap/foreground_start_callback.dart';

class ForegroundServiceController with Logging {
  Future<void> init() async {
    await initForegroundPlugin();
  }

  Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }

  Future<void> startMonitoring() async {
    logI("Starting monitor task");
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Uruchamianie...',
      callback: startCallback,
    );
    logI("Start monitor task result: $result");
  }

  Future<void> restartMonitoring() async {
    logI("Restarting monitor task");
    final result = await FlutterForegroundTask.restartService();
    logI("Restart monitor task result: $result");
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

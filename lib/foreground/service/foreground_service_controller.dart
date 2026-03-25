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
    logI("Started monitor task");
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Uruchamianie...',
      callback: startCallback,
    );
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

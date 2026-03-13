import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../bootstrap/foreground_plugin_init.dart';
import '../bootstrap/foreground_start_callback.dart';

class ForegroundServiceController {
  Future<void> init() async {
    await initForegroundPlugin();
  }

  Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }

  Future<void> startMonitoring() async {
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

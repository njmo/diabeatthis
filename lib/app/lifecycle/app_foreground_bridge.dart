import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../foreground/service/foreground_service_controller.dart';

class AppForegroundBridge {
  AppForegroundBridge() : controller = ForegroundServiceController();

  final ForegroundServiceController controller;

  Future<void> init() async {
    await controller.init();
  }

  void attach(void Function(Object data) onData) {
    FlutterForegroundTask.addTaskDataCallback(onData);
  }

  void detach(void Function(Object data) onData) {
    FlutterForegroundTask.removeTaskDataCallback(onData);
  }

  Future<void> startMonitoring() async {
    final isRunning = await controller.isRunning();
    if (!isRunning) {
      await controller.startMonitoring();
    }
  }
}
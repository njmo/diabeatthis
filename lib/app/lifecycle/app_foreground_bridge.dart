import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../core/logger/logger.dart';
import '../../foreground/service/foreground_service_controller.dart';

class AppForegroundBridge with Logging {
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

  void reInitCommunicationPort() {
    FlutterForegroundTask.initCommunicationPort();
  }

  Future<void> restartService() async {
    await FlutterForegroundTask.restartService();
  }

  Future<bool> isServiceRunning() async {
    return controller.isRunning();
  }

  Future<void> startMonitoring() async {
    await controller.startMonitoring();
  }
}
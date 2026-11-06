import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../foreground/service/foreground_service_controller.dart';

class AppForegroundBridge {
  AppForegroundBridge() : controller = ForegroundServiceController();

  final ForegroundServiceController controller;
  Future<void>? _initialization;
  bool _communicationInitialized = false;

  Future<void> init() async {
    try {
      await (_initialization ??= controller.init());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  void attach(void Function(Object data) onData) {
    FlutterForegroundTask.addTaskDataCallback(onData);
  }

  void detach(void Function(Object data) onData) {
    FlutterForegroundTask.removeTaskDataCallback(onData);
  }

  void reInitCommunicationPort() {
    if (_communicationInitialized) return;
    FlutterForegroundTask.initCommunicationPort();
    _communicationInitialized = true;
  }

  Future<void> restartService() async {
    await init();
    reInitCommunicationPort();
    await controller.restartMonitoring();
  }

  Future<bool> isServiceRunning() async {
    return controller.isRunning();
  }

  Future<void> startMonitoring() async {
    await init();
    reInitCommunicationPort();
    await controller.startMonitoring();
  }
}

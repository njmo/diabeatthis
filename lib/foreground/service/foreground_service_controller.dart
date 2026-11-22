import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../common/app_mode/application_device_mode.dart';
import '../../common/l10n/language.dart';
import '../../core/logger/logger.dart';
import '../bootstrap/foreground_plugin_init.dart';
import '../bootstrap/foreground_start_callback.dart';

class ForegroundServiceController with Logging {
  ForegroundServiceController({this.taskCallback});

  final void Function()? taskCallback;

  Future<void> init() async {
    await initForegroundPlugin();
    final callback = taskCallback;
    if (callback != null && await isRunning()) {
      final result = await FlutterForegroundTask.updateService(
        callback: callback,
      );
      if (result is ServiceRequestFailure) throw result.error;
    }
  }

  Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }

  Future<void> startMonitoring() async {
    if (Platform.isAndroid &&
        await loadApplicationDeviceMode() == ApplicationDeviceMode.caregiver) {
      throw StateError('Patient foreground is disabled in caregiver mode.');
    }
    if (await isRunning()) return;
    if (Platform.isAndroid &&
        !(await Permission.activityRecognition.status).isGranted) {
      throw StateError('Health monitoring permission is required.');
    }
    logI("Starting monitor task");
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: lang.uiStartingMonitoring,
      notificationText: lang.uiStartingMonitoring,
      callback: taskCallback ?? startCallback,
    );
    if (result is ServiceRequestFailure) throw result.error;
    logI("Start monitor task result: $result");
  }

  Future<void> restartMonitoring() async {
    if (Platform.isAndroid &&
        await loadApplicationDeviceMode() == ApplicationDeviceMode.caregiver) {
      throw StateError('Patient foreground is disabled in caregiver mode.');
    }
    logI("Restarting monitor task");
    final result = await FlutterForegroundTask.restartService();
    if (result is ServiceRequestFailure) throw result.error;
    logI("Restart monitor task result: $result");
  }

  Future<void> stop() async {
    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) throw result.error;
  }
}

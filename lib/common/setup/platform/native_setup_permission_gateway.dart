import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/setup_feature.dart';
import '../domain/setup_permission_gateway.dart';

/// All permission dialogs are triggered by an explicit setup action.
class NativeSetupPermissionGateway implements SetupPermissionGateway {
  const NativeSetupPermissionGateway();
  @override
  Future<bool> check(SetupRequirement requirement) async =>
      switch (requirement) {
        SetupRequirement.healthMonitoring =>
          !Platform.isAndroid ||
              (await Permission.activityRecognition.status).isGranted,
        SetupRequirement.notifications =>
          (await Permission.notification.status).isGranted,
        SetupRequirement.camera => (await Permission.camera.status).isGranted,
        SetupRequirement.backgroundExecution =>
          !Platform.isAndroid ||
              await FlutterForegroundTask.isIgnoringBatteryOptimizations,
        SetupRequirement.exactAlarms =>
          !Platform.isAndroid ||
              await FlutterForegroundTask.canScheduleExactAlarms,
        _ => false,
      };
  @override
  Future<bool> request(SetupRequirement requirement) async {
    if (await check(requirement)) return true;
    if (requirement == SetupRequirement.notifications ||
        requirement == SetupRequirement.camera ||
        requirement == SetupRequirement.healthMonitoring) {
      final permission = requirement == SetupRequirement.notifications
          ? Permission.notification
          : requirement == SetupRequirement.healthMonitoring
          ? Permission.activityRecognition
          : Permission.camera;
      if ((await permission.status).isPermanentlyDenied) {
        await openAppSettings();
        return check(requirement);
      }
    }
    switch (requirement) {
      case SetupRequirement.healthMonitoring:
        if (Platform.isAndroid) await Permission.activityRecognition.request();
      case SetupRequirement.notifications:
        await Permission.notification.request();
      case SetupRequirement.camera:
        await Permission.camera.request();
      case SetupRequirement.backgroundExecution:
        if (Platform.isAndroid) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      case SetupRequirement.exactAlarms:
        if (Platform.isAndroid) {
          await FlutterForegroundTask.openAlarmsAndRemindersSettings();
        }
      default:
        return false;
    }
    return check(requirement);
  }
}

import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> initForegroundPlugin() async{
  await _checkAndRequestPermissions();
  _initForegroundTask();
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground',
      channelName: 'Foreground Service Notification',
      channelDescription:
      'This notification appears when the foreground controllers is running.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> _checkAndRequestPermissions() async {
  // Android 13+, you need to allow notification permission to display foreground controllers notification.
  //
  // iOS: If you need notification, ask for permission.
  final notificationPermission =
  await FlutterForegroundTask.checkNotificationPermission();
  if (notificationPermission != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }

  if (Platform.isAndroid) {
    // Android 12+, there are restrictions on starting a foreground controllers.
    //
    // To restart the controllers on device reboot or unexpected problem, you need to allow below permission.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Use this utility only if you provide services that require long-term survival,
    // such as exact alarm controllers, healthcare controllers, or Bluetooth communication.
    //
    // This utility requires the "android.permission.SCHEDULE_EXACT_ALARM" permission.
    // Using this permission may make app distribution difficult due to Google policy.
    if (!await FlutterForegroundTask.canScheduleExactAlarms) {
      // When you call this function, will be gone to the settings page.
      // So you need to explain to the user why set it.
      await FlutterForegroundTask.openAlarmsAndRemindersSettings();
    }
  }
}


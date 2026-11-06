import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> initForegroundPlugin() async {
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
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: false,
      allowWifiLock: false,
    ),
  );
}

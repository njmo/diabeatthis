import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class MyTaskHandler extends TaskHandler {
  bool isUiRunning = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Oczekiwanie na dane...',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny $isUiRunning',
      notificationText: 'Ostatni sync: ${DateTime.now()}',
    );
  }

  // Called when the handlers is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('onDestroy(isTimeout: $isTimeout)');
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      if (data['event'] == 'app_lifecycle_change') {
        final stateIndex = data['data']['state'] as int;
        final state = AppLifecycleState.values[stateIndex];
        isUiRunning = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
      }
    }
    print('onReceiveData: $data');
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }
}
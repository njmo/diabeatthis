import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../app/router/observers/riverpod_debug_observer.dart';
import '../event/handlers/task_event_handler.dart';

class MyTaskHandler extends TaskHandler {
  bool isUiRunning = false;
  ProviderContainer? _container;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _container = ProviderContainer(
      observers: [RiverpodDebugObserver(env: 'fg')],
    );

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Oczekiwanie na dane...',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final appState = _container?.read(appLifecycleProvider);
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny $appState',
      notificationText: 'Ostatni tick: ${DateTime.now()}',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _container?.dispose();
    _container = null;
    print('onDestroy(isTimeout: $isTimeout)');
  }

  @override
  void onReceiveData(Object data) {
    final uiEventHandler = TaskEventHandler(_container!);
    if (data is Map<String, dynamic>) {
      uiEventHandler.handle(data);
    }
    print('onReceiveData: $data');
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }
}

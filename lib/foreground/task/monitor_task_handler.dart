import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../app/router/observers/riverpod_debug_observer.dart';
import '../../core/notifications/domain/events/eat_now_event_notification.dart';
import '../../core/notifications/providers/notifications_controller_provider.dart';
import '../event/app/app_event_handler.dart';

class MyTaskHandler extends TaskHandler {
  bool isUiRunning = false;
  ProviderContainer? _container;
  AppEventHandler? _appEventHandler;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _container = ProviderContainer(
      observers: [RiverpodDebugObserver(env: 'fg')],
    );
    _appEventHandler = AppEventHandler(_container!);

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
    if (data is String) {
      final map = jsonDecode(data) as Map<String, dynamic>;
      _appEventHandler!.handle(map);
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

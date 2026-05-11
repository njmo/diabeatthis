import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/observers/riverpod_debug_observer.dart';
import '../../core/logger/logger.dart';
import '../collector/device_status_collector.dart';
import '../collector/foreground_collector.dart';
import '../collector/meal_status_collector.dart';
import '../collector/next_activity_collector.dart';
import '../collector/next_meal_collector.dart';
import '../collector/treatments_collector.dart';
import '../event/external/external_event_handler.dart';
import '../synchronization/synchronization_cache_controller.dart';
import '../task/base/collector_context.dart';
import '../task/tasks/activity_monitor_task/activity_monitor_task.dart';
import '../task/tasks/meal_monitor_task/meal_monitor_task.dart';
import '../task/tasks/service_status_updater_task.dart';
import '../task/tasks/temp_target_monitor_task.dart';
import 'workflow_scheduler.dart';

class MyTaskHandler extends TaskHandler with Logging {
  bool isUiRunning = false;

  ProviderContainer? _container;
  ExternalEventHandler? _externalEventHandler;
  WorkflowScheduler? _taskScheduler;
  List<ForegroundCollector>? _collectors;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _container = ProviderContainer(
      observers: [if (kDebugMode) RiverpodDebugObserver(env: 'fg')],
    );

    LogRuntimeConfig.configure(enableBuffer: true, capacity: 20000);

    await _container!
        .read(synchronizationCacheControllerProvider)
        .init(_container!);

    _taskScheduler = WorkflowScheduler();

    final runtimeContext = _taskScheduler!.createContext(_container!);

    final collectorContext = CollectorContext.fromRuntimeContext(
      runtimeContext,
    );

    final tasks = [
      MealMonitorTask(),
      ActivityMonitorTask(),
      ServiceStatusUpdaterTask(),
      TempTargetMonitorTask(),
    ];
    for (final task in tasks) {
      _taskScheduler!.startTask(task, runtimeContext);
    }

    _collectors = [
      DeviceStatusCollector(),
      NextActivityCollector(),
      NextMealCollector(),
      MealStatusCollector(),
      TreatmentsCollector(),
    ];
    for (final collector in _collectors!) {
      collector.start(collectorContext);
    }

    _externalEventHandler = ExternalEventHandler(runtimeContext);

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Oczekiwanie na dane...',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _container?.dispose();
    _container = null;
    _externalEventHandler = null;
    _taskScheduler = null;

    logI('onDestroy(isTimeout: $isTimeout)');
  }

  @override
  void onReceiveData(Object data) {
    logI('onReceiveData: $data');

    final handler = _externalEventHandler;
    if (handler == null) return;

    try {
      if (data is String) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        handler.handle(map);
        return;
      }

      logW('Unsupported data type: ${data.runtimeType}');
    } catch (e, st) {
      logE('Error handling data: $e\n$st');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    logI('onNotificationButtonPressed: $id');
  }

  @override
  void onNotificationPressed() {
    logI('onNotificationPressed');
  }

  @override
  void onNotificationDismissed() {
    logI('onNotificationDismissed');
  }
}

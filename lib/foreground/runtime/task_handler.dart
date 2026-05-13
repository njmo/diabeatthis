import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/observers/riverpod_debug_observer.dart';
import '../../common/events/data/task/task_state_synchronization_payload.dart';
import '../../core/logger/logger.dart';
import '../collector/device_status_collector.dart';
import '../collector/foreground_collector.dart';
import '../collector/glucose_collector.dart';
import '../collector/meal_status_collector.dart';
import '../collector/next_activity_collector.dart';
import '../collector/next_meal_collector.dart';
import '../collector/treatments_collector.dart';
import '../event/external/external_event_handler.dart';
import '../providers/task_event_router_provider.dart';
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
  final List<Object> _pendingData = [];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    logI('onStart(starter: $starter)');

    _container = ProviderContainer(
      observers: [if (kDebugMode) RiverpodDebugObserver(env: 'fg')],
    );

    LogRuntimeConfig.configure(enableBuffer: true, capacity: 20000);

    _taskScheduler = WorkflowScheduler();

    final runtimeContext = _taskScheduler!.createContext(_container!);
    _externalEventHandler = ExternalEventHandler(runtimeContext);
    _container!
        .read(taskEventRouterProvider)
        .send(const TaskStateSynchronizationPayload.alive(data: true));

    final cacheInit = _container!
        .read(synchronizationCacheControllerProvider)
        .init(_container!);
    _flushPendingData();
    unawaited(cacheInit);

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
      GlucoseCollector(),
      DeviceStatusCollector(),
      NextActivityCollector(),
      NextMealCollector(),
      MealStatusCollector(),
      TreatmentsCollector(),
    ];
    for (final collector in _collectors!) {
      collector.start(collectorContext);
    }

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
    _pendingData.clear();

    logI('onDestroy(isTimeout: $isTimeout)');
  }

  @override
  void onReceiveData(Object data) {
    logI('onReceiveData: $data');

    final handler = _externalEventHandler;
    if (handler == null) {
      logI('External event handler is not ready, queueing data');
      _pendingData.add(data);
      return;
    }

    _handleData(handler, data);
  }

  void _flushPendingData() {
    final handler = _externalEventHandler;
    if (handler == null || _pendingData.isEmpty) return;

    logI('Flushing ${_pendingData.length} pending app events');
    final data = List<Object>.from(_pendingData);
    _pendingData.clear();

    for (final item in data) {
      _handleData(handler, item);
    }
  }

  void _handleData(ExternalEventHandler handler, Object data) {
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
    FlutterForegroundTask.launchApp('/');
  }
}

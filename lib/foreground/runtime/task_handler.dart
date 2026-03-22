import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../collector/blood_sugar_collector.dart';
import '../collector/device_status_collector.dart';
import '../collector/foreground_collector.dart';
import '../collector/meal_status_collector.dart';
import '../collector/next_meal_collector.dart';
import '../collector/treatments_collector.dart';
import '../event/external/external_event_handler.dart';
import '../task/base/collector_context.dart';
import '../task/tasks/meal_monitor_task/meal_monitor_task.dart';
import '../task/tasks/service_status_updater_task.dart';
import 'workflow_scheduler.dart';

class MyTaskHandler extends TaskHandler {
  bool isUiRunning = false;

  ProviderContainer? _container;
  ExternalEventHandler? _externalEventHandler;
  WorkflowScheduler? _taskScheduler;
  List<ForegroundCollector>? _collectors;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _container = ProviderContainer(
      // observers: [RiverpodDebugObserver(env: 'fg')],
    );

    LogRuntimeConfig.configure(enableBuffer: true, capacity: 20000);

    _taskScheduler = WorkflowScheduler();

    final runtimeContext = _taskScheduler!.createContext(_container!);

    final collectorContext = CollectorContext.fromRuntimeContext(
      runtimeContext,
    );

    _collectors = [
      DeviceStatusCollector(),
      BloodSugarCollector(),
      MealStatusCollector(),
      NextMealCollector(),
      TreatmentsCollector(),
    ];
    for (final collector in _collectors!) {
      collector.start(collectorContext);
    }

    final tasks = [MealMonitorTask(), ServiceStatusUpdaterTask()];
    for (final task in tasks) {
      _taskScheduler!.startTask(task, runtimeContext);
    }

    _externalEventHandler = ExternalEventHandler(runtimeContext);

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Oczekiwanie na dane...',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // if (_taskScheduler == null) return;
    //
    // _taskScheduler!.debugPrintState();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _container?.dispose();
    _container = null;
    _externalEventHandler = null;
    _taskScheduler = null;

    print('onDestroy(isTimeout: $isTimeout)');
  }

  @override
  void onReceiveData(Object data) {
    print('onReceiveData: $data');

    final handler = _externalEventHandler;
    if (handler == null) return;

    try {
      if (data is String) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        handler.handle(map);
        return;
      }

      print('Unsupported data type: ${data.runtimeType}');
    } catch (e, st) {
      print('Error handling data: $e\n$st');
    }
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

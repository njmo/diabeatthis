import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/observers/riverpod_debug_observer.dart';
import '../collector/foreground_collector.dart';
import '../collector/meal_status_collector.dart';
import '../collector/next_meal_collector.dart';
import '../event/external/external_event_handler.dart';
import '../task/base/task_context.dart';
import '../task/tasks/meal_monitor_task.dart';
import '../task/tasks/service_status_updater_task.dart';
import 'event_dispatcher.dart';
import 'task_scheduler.dart';

class MyTaskHandler extends TaskHandler {
  bool isUiRunning = false;

  ProviderContainer? _container;
  ExternalEventHandler? _externalEventHandler;
  EventDispatcher? _dispatcher;
  TaskScheduler? _taskScheduler;
  TaskContext? _taskContext;
  List<ForegroundCollector>? _collectors;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _container = ProviderContainer(
      observers: [RiverpodDebugObserver(env: 'fg')],
    );

    _dispatcher = EventDispatcher();

    _externalEventHandler = ExternalEventHandler(_container!, _dispatcher!);

    _taskContext = TaskContext(
      container: _container!,
      dispatcher: _dispatcher!,
    );

    _taskScheduler = TaskScheduler(
      context: _taskContext!,
      tasks: [MealMonitorTask(), ServiceStatusUpdaterTask()],
    );

    _collectors = [
      MealStatusCollector(_container!),
      NextMealCollector(_container!),
    ];

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny',
      notificationText: 'Oczekiwanie na dane...',
    );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    for (final collector in _collectors!) {
      try {
        await collector.collect(_dispatcher!);
      } catch (e, st) {
        print('Error in collector.collect(): $e\n$st');
      }
    }

    while (_dispatcher!.hasPendingEvents) {
      final event = _dispatcher!.tryDequeue();
      if (event == null) break;

      try {
        await _taskScheduler!.handleEvent(event);
      } catch (e, st) {
        print('Error in scheduler.handleEvent($event): $e\n$st');
      }
    }

    try {
      await _taskScheduler!.tick();
    } catch (e, st) {
      print('Error in scheduler.tick(): $e\n$st');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _container?.dispose();
    _container = null;
    _externalEventHandler = null;
    _dispatcher = null;
    _taskScheduler = null;
    _taskContext = null;

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

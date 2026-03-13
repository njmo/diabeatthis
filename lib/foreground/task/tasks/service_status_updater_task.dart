import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/events/data/app/lifecycle_state_event.dart';
import '../../event/model/foreground_event.dart';
import '../base/event_matcher.dart';
import '../base/foreground_task.dart';
import '../base/task_context.dart';


class ServiceStatusUpdaterTask extends ForegroundTask {
  AppLifecycleState _appState = AppLifecycleState.resumed;
  bool _appLifecycleChanged = true;

  @override
  List<EventMatcher> get eventMatchers => [
    EventMatcher.type<LifecycleStateEvent>(),
  ];

  @override
  Future<void> onEvent(ForegroundEvent event, TaskContext context) async {
    if (event is LifecycleStateEvent) {
      _appState = event.when(changed: (state) => AppLifecycleState.values[state]);
      _appLifecycleChanged = true;
      context.log('ServiceStatusUpdaterTask: ui isolate sate changed to $_appState');
      return;
    }
  }

  @override
  Future<void> onTick(TaskContext context) async {
    if (!_appLifecycleChanged) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Monitoring aktywny $_appState',
      notificationText: 'Ostatna zmiana: ${DateTime.now()}',
    );
  }
}
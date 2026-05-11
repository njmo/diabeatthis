import 'package:flutter/foundation.dart';

import '../../../../core/logger/logger.dart';
import '../../../event/internal/activity_event.dart';
import '../../../event/model/foreground_event.dart';
import '../../base/runtime_context.dart';
import '../../base/workflow_task.dart';
import 'activity_monitor_context.dart';
import 'activity_monitor_transition.dart';
import 'executors/activity_monitor_state_executor.dart';
import 'executors/finish_activity_executor.dart';
import 'executors/idle_executor.dart';
import 'executors/monitor_active_activity_executor.dart';
import 'executors/monitor_until_activity_executor.dart';
import 'executors/new_activity_check_executor.dart';
import 'helpers/activity_monitor_context_loader.dart';

class ActivityMonitorTask extends InterruptableWorkflowTask with Logging {
  @override
  List<bool Function(ForegroundEvent)> get interruptableEventsMatcher => [
    (e) => e is NextActivityEvent,
    (e) => e is ActivityStartedEvent,
    (e) => e is ActivityStoppedEvent,
    (e) => e is ActivityCancelledEvent,
  ];

  @visibleForTesting
  ActivityMonitorStateExecutor get state => _state;

  ActivityMonitorStateExecutor _state = const ActivityMonitorStateIdle();
  ActivityMonitorContext _activityMonitorContext = ActivityMonitorContext();

  @override
  bool shouldInterrupt(ForegroundEvent event) {
    logI("ActivityMonitorTask shouldInterrupt ${event.runtimeType}");
    if (_state.interruptableEvents.contains(event.runtimeType)) {
      return _state.shouldInterrupt(event, _activityMonitorContext);
    }
    return false;
  }

  void _transitionTo({
    ActivityMonitorContext? nextActivityMonitorContext,
    required RuntimeContext context,
    required ActivityMonitorStateExecutor nextExecutor,
  }) {
    if (_state.runtimeType == nextExecutor.runtimeType &&
        nextActivityMonitorContext == null) {
      return;
    }

    logI("Transition to ${nextExecutor.runtimeType}");
    _state.cleanup(context, _activityMonitorContext);

    if (nextActivityMonitorContext != null) {
      _activityMonitorContext = nextActivityMonitorContext;
    }

    _state = nextExecutor;
  }

  Future<ActivityMonitorContext?> buildActivityMonitorContext(
    RuntimeContext context,
    int activityLogId,
  ) {
    return loadActivityMonitorContext(context, activityLogId);
  }

  @override
  Future<void> runLoop(
    RuntimeContext context, {
    ForegroundEvent? interruptedEvent,
  }) async {
    logI("ActivityMonitorTask runLoop ${interruptedEvent.runtimeType}");

    ActivityMonitorTransition? transition;

    switch (interruptedEvent) {
      case NextActivityEvent():
        final nextContext = await buildActivityMonitorContext(
          context,
          interruptedEvent.activityLogId,
        );

        if (nextContext != null) {
          transition = ActivityMonitorTransition(
            nextContext,
            const MonitorUntilActivityExecutor(),
          );
        } else {
          transition = ActivityMonitorTransition(
            ActivityMonitorContext(),
            const NewActivityCheckExecutor(),
          );
        }
        break;
      case ActivityStartedEvent():
        final nextContext = await buildActivityMonitorContext(
          context,
          interruptedEvent.activityLogId,
        );

        if (nextContext != null) {
          transition = ActivityMonitorTransition(
            nextContext,
            const MonitorActiveActivityExecutor(),
          );
        }
        break;
      case ActivityStoppedEvent(:final activityLogId):
      case ActivityCancelledEvent(:final activityLogId):
        if (activityLogId == _activityMonitorContext.activityLogId) {
          transition = ActivityMonitorTransition(
            null,
            const FinishActivityExecutor(),
          );
        }
        break;
      default:
        transition = ActivityMonitorTransition(
          ActivityMonitorContext(),
          const NewActivityCheckExecutor(),
        );
    }

    if (transition != null) {
      _transitionTo(
        nextExecutor: transition.executor,
        nextActivityMonitorContext: transition.context,
        context: context,
      );
    }

    while (true) {
      final nextState = await _state.execute(context, _activityMonitorContext);
      _transitionTo(nextExecutor: nextState, context: context);
    }
  }
}

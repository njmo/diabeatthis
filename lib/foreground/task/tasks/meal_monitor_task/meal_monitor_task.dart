import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../common/monitoring/meal_monitoring_status.dart';
import '../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../event/internal/meal_event.dart';
import '../../../event/internal/meal_status_changed_event.dart';
import '../../../event/internal/monitoring_status_changed.dart';
import '../../../event/model/foreground_event.dart';
import '../../base/runtime_context.dart';
import '../../base/workflow_task.dart';
import 'executors/idle_executor.dart';
import 'executors/meal_monitor_state_executor.dart';
import 'executors/monitor_until_meal.dart';
import 'executors/new_meal_check_executor.dart';
import 'helpers/meal_status_to_executor_mapper.dart';
import 'meal_monitor_context.dart';
import 'meal_monitor_transition.dart';

class MealMonitorTask extends InterruptableWorkflowTask with Logging {
  @override
  ForegroundEvent get unexpectedStopEvent => const MealMonitoringStatusChanged(
    MealMonitoringStatus(phase: MealMonitoringPhase.unavailable),
  );

  @override
  List<bool Function(ForegroundEvent)> get interruptableEventsMatcher => [
    (e) => e is NextMealEvent || e is PlannedMealsClearedEvent,
    (e) => e is MealStatusChangedEvent,
  ];

  @visibleForTesting
  MealMonitorStateExecutor get state => _state;

  @override
  bool shouldInterrupt(ForegroundEvent event) {
    logI("MealMonitorTask shouldInterrupt ${event.runtimeType}");
    if (event is PlannedMealsClearedEvent) {
      if (_loadingMealId != null) return _loadingPlannedMeal;
      return _state is MonitorUntilMeal || _state is NewMealCheckExecutor;
    }
    if (event is MealEatingExtraEvent &&
        _stoppedMeals[event.mealId] is MealSummarizedEvent) {
      // A new, persisted add-on may intentionally reopen a completed summary.
      _stoppedMeals.remove(event.mealId);
    }
    if (event is MealInterruptedEvent || event is MealSummarizedEvent) {
      final terminalEvent = event as MealStatusChangedEvent;
      _stoppedMeals[terminalEvent.mealId] = terminalEvent;
      if (_activeMealExecutorContext.activeMeal?.id == terminalEvent.mealId) {
        _activeMealExecutorContext.stop(terminalEvent);
        return true;
      }
      if (_loadingMealId == terminalEvent.mealId) {
        return true;
      }
      return false;
    }
    if (_state.interruptableEvents.contains(event.runtimeType)) {
      return _state.shouldInterrupt(event, _activeMealExecutorContext);
    }
    return false;
  }

  MealMonitorStateExecutor _state = MealMonitorStateIdle();
  MealMonitorContext _activeMealExecutorContext = MealMonitorContext();
  int? _loadingMealId;
  bool _loadingPlannedMeal = false;
  final Map<int, MealStatusChangedEvent> _stoppedMeals = {};

  void _throwIfMealStopped(RuntimeContext context) {
    final event = _stoppedMeals[_activeMealExecutorContext.activeMeal?.id];
    if (event != null) _activeMealExecutorContext.stop(event);
    _activeMealExecutorContext.throwIfStopped(context);
  }

  void _transitionTo({
    MealMonitorContext? nextMealExecutorContext,
    required RuntimeContext context,
    required MealMonitorStateExecutor nextExecutor,
  }) {
    // if state did not change we do nothing
    // if there is no context change we do nothing
    if (_state.runtimeType == nextExecutor.runtimeType &&
        nextMealExecutorContext == null) {
      return;
    }
    logI("Transition to ${nextExecutor.runtimeType}");
    if (nextMealExecutorContext != null) {
      _state.cleanup(context, _activeMealExecutorContext);
      _activeMealExecutorContext = nextMealExecutorContext;
    } else {
      _state.cleanup(context, _activeMealExecutorContext);
    }
    _state = nextExecutor;
  }

  Future<MealMonitorContext> buildMealMonitorContext(
    RuntimeContext context,
    int mealId,
  ) async {
    _loadingMealId = mealId;
    try {
      context.container.invalidate(getMealByIdProvider(mealId));
      final meal = await context.container.read(
        getMealByIdProvider(mealId).future,
      );
      final nextContext = MealMonitorContext(activeMeal: meal);
      final stopEvent = _stoppedMeals[mealId];
      if (stopEvent != null) nextContext.stop(stopEvent);
      return nextContext;
    } finally {
      _loadingMealId = null;
    }
  }

  @override
  Future<void> runLoop(
    RuntimeContext context, {
    ForegroundEvent? interruptedEvent,
  }) async {
    logI("MealMonitorTask runLoop ${interruptedEvent.runtimeType}");

    MealMonitorTransition? mealMonitorTransition;

    switch (interruptedEvent) {
      case PlannedMealsClearedEvent():
        final removedMealId = _activeMealExecutorContext.activeMeal?.id;
        if (removedMealId != null) {
          try {
            await context.container
                .read(notificationsControllerForegroundProvider)
                .cancelMealNotifications(
                  removedMealId,
                  includeTargetConsent: true,
                );
          } catch (error, stackTrace) {
            // A platform cancellation failure must not keep a deleted meal active.
            logW(
              'Could not cancel notifications for removed meal $removedMealId: $error\n$stackTrace',
            );
          }
        }
        context.container.invalidate(getNearestMealProvider);
        mealMonitorTransition = MealMonitorTransition(
          MealMonitorContext(),
          MealMonitorStateIdle(),
        );
        break;
      case NextMealEvent():
        // user added new meal which is nearer than previous
        // reset whole state machine and perform cleanup
        // if currently monitoring meal is still in planned phase we are
        // just monitoring and user added something now which is nearer
        // than our observed meal, otherwise we need to ignore this
        // this will be handled by MonitorUntilMealExecutor state
        // if we come here it means this is new meal we want to focus on.
        late final MealMonitorContext nextMealExecutorContext;
        _loadingPlannedMeal = true;
        try {
          nextMealExecutorContext = await buildMealMonitorContext(
            context,
            interruptedEvent.mealId,
          );
        } finally {
          _loadingPlannedMeal = false;
        }
        // The candidate may have changed status while its row was loading.
        final latestMeal = nextMealExecutorContext.activeMeal;
        final nextExecutor = latestMeal == null
            ? NewMealCheckExecutor()
            : mealStatusChangedEventToExecutor(
                    MealStatusChangedEvent.fromMealStatus(latestMeal),
                    true,
                  ) ??
                  NewMealCheckExecutor();
        mealMonitorTransition = MealMonitorTransition(
          nextMealExecutorContext,
          nextExecutor,
        );
        break;
      case MealStatusChangedEvent():
        // user or state machine changed state of the meal in database
        // force current state cleanup and move to another state
        // if true, user is doing something on the meal we are not monitoring
        // executors will take care of checking if event is meaningful in the
        // current context
        final eventForActiveMeal =
            _activeMealExecutorContext.activeMeal?.id ==
            interruptedEvent.mealId;

        final terminal =
            interruptedEvent is MealInterruptedEvent ||
            interruptedEvent is MealSummarizedEvent;
        if (terminal) {
          final nextExecutor = mealStatusChangedEventToExecutor(
            interruptedEvent,
            eventForActiveMeal,
          );
          if (nextExecutor != null) {
            mealMonitorTransition = MealMonitorTransition(
              MealMonitorContext(),
              nextExecutor,
            );
          }
          break;
        }

        MealMonitorContext? nextMealExecutorContext;
        // if event is not for active meal and this is not meal skipped event
        if (!eventForActiveMeal && interruptedEvent is! MealSkippedEvent) {
          // meal changed we need to store for active cleanup
          // we will change state to new context and cleanup the old one
          nextMealExecutorContext = await buildMealMonitorContext(
            context,
            interruptedEvent.mealId,
          );
        }
        if (eventForActiveMeal && interruptedEvent is MealSkippedEvent) {
          nextMealExecutorContext = _activeMealExecutorContext.copyWith(
            activeMeal: null,
          );
        } else if (eventForActiveMeal) {
          nextMealExecutorContext = await buildMealMonitorContext(
            context,
            interruptedEvent.mealId,
          );
        }

        // pick next state based on interrupted event type
        // user may decide to eat another meal or skip current meal
        // we need to act accordingly.
        final nextExecutor = mealStatusChangedEventToExecutor(
          interruptedEvent,
          eventForActiveMeal,
        );
        if (nextExecutor != null) {
          mealMonitorTransition = MealMonitorTransition(
            nextMealExecutorContext,
            nextExecutor,
          );
          break;
        }
        break;
      default:
        // no event interrupted we may be probably entering this loop for the
        // first time, since we were not waiting for NextMealEvent before,
        // we need to manually check if we there is something to monitor
        // and act accordingly.
        mealMonitorTransition = MealMonitorTransition(
          MealMonitorContext(),
          NewMealCheckExecutor(),
        );
    }

    if (mealMonitorTransition != null) {
      _transitionTo(
        nextExecutor: mealMonitorTransition.executor,
        nextMealExecutorContext: mealMonitorTransition.context,
        context: context,
      );
    }

    // execute main state machine loop till interrupt.
    while (true) {
      _throwIfMealStopped(context);
      final nextState = await _state.execute(
        context,
        _activeMealExecutorContext,
      );
      _throwIfMealStopped(context);
      _transitionTo(nextExecutor: nextState, context: context);
    }
  }
}

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../event/internal/meal_event.dart';
import '../../../event/internal/meal_status_changed_event.dart';
import '../../../event/model/foreground_event.dart';
import '../../base/runtime_context.dart';
import '../../base/workflow_task.dart';
import 'executors/bolus_then_wait_executor.dart';
import 'executors/detect_finished_eating_executor.dart';
import 'executors/finalize_meal_executor.dart';
import 'executors/idle_executor.dart';
import 'executors/meal_monitor_state_executor.dart';
import 'executors/monitor_until_meal.dart';
import 'meal_monitor_context.dart';
import 'meal_monitor_transition.dart';

class MealMonitorTask extends InterruptableWorkflowTask with Logging {
  @override
  List<bool Function(ForegroundEvent)> get interruptableEventsMatcher => [
        (e) => e is NextMealEvent,
        (e) => e is MealStatusChangedEvent,
  ];

  @visibleForTesting
  MealMonitorStateExecutor get state => _state;

  @override
  bool shouldInterrupt(ForegroundEvent event) {
    logI("MealMonitorTask shouldInterrupt ${event.runtimeType}");
    if (_state.interuptableEvents.contains(event.runtimeType)) {
      return _state.shouldInterrupt(event, _activeMealExecutorContext);
    }
    return false;
  }

  MealMonitorStateExecutor? _mealStatusChangedEventToExecutor(
    MealStatusChangedEvent event,
    bool eventForActiveMeal,
  ) {
    return event.map(
      eating: (MealStartedEatingEvent value) =>
          DetectFinishedEatingExecutor(shouldBolus: false),
      eaten: (MealFinishedEatingEvent value) => FinalizeMealExecutor(),
      skipped: (MealSkippedEvent value) {
        if (eventForActiveMeal) {
          return MealMonitorStateIdle();
        }
        // ignore this transition
        return null;
      },
      eatingThenBolus: (MealEatingThenBolus value) =>
          DetectFinishedEatingExecutor(shouldBolus: true),
      bolusedWaiting: (MealBolusedWaitingEvent value) =>
          BolusThenWaitExecutor(recommendedMinutes: null),
      bolusedEating: (MealBolusedEatingEvent value) =>
          DetectFinishedEatingExecutor(shouldBolus: false),
      eatenBolused: (MealFinishedEatingBolusedEvent value) =>
          FinalizeMealExecutor(),
      planned: (MealPlannedEvent value) => MonitorUntilMeal(),
    );
  }

  Future<Meal?> checkForNextMeal(RuntimeContext context) async {
    final meal = await context.container.read(getNearestMealProvider.future);
    return meal;
  }

  MealMonitorStateExecutor _state = MealMonitorStateIdle();
  MealMonitorContext _activeMealExecutorContext = MealMonitorContext();

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
    final meal = await context.container.read(
      getMealByIdProvider(mealId).future,
    );
    return MealMonitorContext(activeMeal: meal);
  }

  @override
  Future<void> runLoop(
    RuntimeContext context, {
    ForegroundEvent? interruptedEvent,
  }) async {
    logI("MealMonitorTask runLoop ${interruptedEvent.runtimeType}");

    MealMonitorTransition? mealMonitorTransition;

    switch (interruptedEvent) {
      case NextMealEvent():
        // user added new meal which is nearer than previous
        // reset whole state machine and perform cleanup
        // if currently monitoring meal is still in planned phase we are
        // just monitoring and user added something now which is nearer
        // than our observed meal, otherwise we need to ignore this
        // this will be handled by MonitorUntilMealExecutor state
        // if we come here it means this is new meal we want to focus on.
        final nextMealExecutorContext = await buildMealMonitorContext(
          context,
          interruptedEvent.mealId,
        );
        // NewMealEvent is raised only when created meal has planned state
        // and is sooner than currently monitored, we know proper executor.
        mealMonitorTransition = MealMonitorTransition(
          nextMealExecutorContext,
          MonitorUntilMeal(),
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
        }

        // pick next state based on interrupted event type
        // user may decide to eat another meal or skip current meal
        // we need to act accordingly.
        final nextExecutor = _mealStatusChangedEventToExecutor(
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
        final nextMeal = await checkForNextMeal(context);
        if (nextMeal == null) {
          logI("No meal to monitor, wait for NextMealEvent and sleep.");
          // no meal to monitor, wait for NextMealEvent and sleep.
          mealMonitorTransition = MealMonitorTransition(
            MealMonitorContext(),
            MealMonitorStateIdle(),
          );
          break;
        }

        if(nextMeal.plannedAt!.isAfter(clock.now())) {
          // map status to proper event
          final mealStateEvent = MealStatusChangedEvent.fromMealStatus(nextMeal);
          final nextExecutor = _mealStatusChangedEventToExecutor(
            mealStateEvent,
            true,
          );

        if (nextExecutor != null) {
          mealMonitorTransition = MealMonitorTransition(
            MealMonitorContext(activeMeal: nextMeal),
            nextExecutor,
          );
        }
        }
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
      final nextState = await _state.execute(
        context,
        _activeMealExecutorContext,
      );
      _transitionTo(nextExecutor: nextState, context: context);
    }
  }
}

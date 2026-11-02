import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/events/data/task/task_state_synchronization_payload.dart';
import '../../../common/meal/open_meal_completion.dart';
import '../../../common/meal/pending_meal_completion_recovery.dart';
import '../../../common/meal/pending_meal_completion_requests.dart';
import '../../../common/navigation/deferred_ui_action.dart';
import '../../../core/domain/model/meal_status_flow.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/notification_event_factory.dart';
import '../../../core/notifications/handlers/notification_response_handler.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../features/low_treatment/presentation/controllers/low_treatment_sheet_launcher.dart';
import '../../providers/foreground_task_state_provider.dart';
import '../../router/providers/app_router_provider.dart';
import '../bridge/data_synchronization_bridge.dart';
import 'task_event.dart';

class TaskEventHandler with Logging {
  final WidgetRef _ref;
  final DataSynchronizationBridge synchronizationDataBridge;
  bool _recoveringMealCompletion = false;
  bool _disposed = false;

  TaskEventHandler(this._ref)
    : synchronizationDataBridge = DataSynchronizationBridge(_ref);

  late final _lowTreatmentLauncher = LowTreatmentSheetLauncher(
    getContext: () => _ref.read(appRouterProvider).navigatorKey.currentContext,
  );

  late final _mealCompletionLauncher = DeferredUiAction<int>(
    getContext: () => _ref.read(appRouterProvider).navigatorKey.currentContext,
    open: (context, mealId) async {
      final meal = await _ref
          .read(databaseProvider)
          .mealDao
          .getMealById(mealId);
      if (_disposed || !context.mounted) return;
      final requests = _ref.read(pendingMealCompletionRequestsProvider);
      if (meal == null ||
          (!mealStatusesStartingEating.contains(meal.status) &&
              meal.status != 'eating-extra' &&
              !mealStatusReadyToSummarize(meal.status))) {
        await requests.acknowledge(mealId);
        return;
      }
      await openMealCompletion(
        context,
        mealId: mealId,
        router: _ref.read(appRouterProvider),
      );
      await requests.acknowledge(mealId);
    },
  );

  void handle(Map<String, dynamic> event) {
    logI('Received event: $event');
    final appEvent = TaskEvent.fromJson(event);

    switch (appEvent) {
      case TaskInAppNotificationEvent(data: final payload):
        logI('Showing notification: $payload');

        final event = NotificationEventFactory().fromPayload(
          payload.type,
          payload.data,
        );
        _ref.read(notificationsControllerUiProvider).show(event);
        break;
      case TaskDataSynchronizationEvent(data: final payload):
        synchronizationDataBridge.handle(payload);
        break;
      case TaskStateSynchronizationEvent(data: final payload):
        logI('Received task state synchronization: $payload');
        payload.when(
          alive: (data) {
            _ref.read(foregroundTaskStateProvider.notifier).setAlive(data);
          },
        );
        break;
      case TaskOpenLowTreatmentEvent():
        _lowTreatmentLauncher.requestOpen();
        break;
      case TaskOpenMealCompletionEvent(data: final payload):
        _mealCompletionLauncher.request(payload.mealId);
        break;
    }
  }

  void retryPendingUiActions() {
    _lowTreatmentLauncher.retryPending();
    _mealCompletionLauncher.retryPending();
    unawaited(recoverPendingMealCompletions());
  }

  Future<void> recoverPendingMealCompletions() async {
    if (_disposed || _recoveringMealCompletion) return;
    _recoveringMealCompletion = true;
    try {
      final pending = await PendingMealCompletionRecovery(
        database: _ref.read(databaseProvider),
        requests: _ref.read(pendingMealCompletionRequestsProvider),
      ).recover(replayFresh: replayFinishedEatingConfirmation);
      if (_disposed) return;
      for (final mealId in pending) {
        _mealCompletionLauncher.request(mealId);
      }
    } catch (error, stackTrace) {
      logE(
        'Could not recover meal completion navigation',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _recoveringMealCompletion = false;
    }
  }

  void dispose() {
    _disposed = true;
    _lowTreatmentLauncher.dispose();
    _mealCompletionLauncher.dispose();
  }
}

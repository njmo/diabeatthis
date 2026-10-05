import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/events/data/task/task_state_synchronization_payload.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/notification_event_factory.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../features/low_treatment/presentation/controllers/low_treatment_sheet_launcher.dart';
import '../../providers/foreground_task_state_provider.dart';
import '../../router/providers/app_router_provider.dart';
import '../bridge/data_synchronization_bridge.dart';
import 'task_event.dart';

class TaskEventHandler with Logging {
  final WidgetRef _ref;
  final DataSynchronizationBridge synchronizationDataBridge;

  TaskEventHandler(this._ref)
    : synchronizationDataBridge = DataSynchronizationBridge(_ref);

  late final _lowTreatmentLauncher = LowTreatmentSheetLauncher(
    getContext: () => _ref.read(appRouterProvider).navigatorKey.currentContext,
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
    }
  }

  void retryPendingUiActions() => _lowTreatmentLauncher.retryPending();

  void dispose() => _lowTreatmentLauncher.dispose();
}

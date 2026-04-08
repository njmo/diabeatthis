import 'dart:ui';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/logger/logger.dart';
import '../../event/internal/treatment_available_event.dart';
import '../../providers/task_event_router_provider.dart';
import '../../synchronization/synchronization_cache_controller.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

class TempTargetMonitorTask extends WorkflowTask with Logging {
  @override
  Future<void> run(RuntimeContext context) async {
    final cache = context.container.read(
      synchronizationCacheControllerProvider,
    );

    while (true) {
      final event = await context
          .waitForEvent<TreatmentAvailableEvent<TemporaryTarget>>();
      logI("Temporary target detected, monitoring started");
      final last = event.data;
      if (context.container.read(appLifecycleProvider) ==
          AppLifecycleState.resumed) {
        final payload = TaskTargetSynchronization(data: last);
        context.container.read(taskEventRouterProvider).send(payload);
      }
      cache.cacheTarget(last);

      while (true) {
        try {
          final current = await context.container.read(
            temporaryTargetByIdProvider(last.nightscoutId).future,
          );

          if (!current.isActive()) {
            logI("Temporary is not active, monitoring stopped");

            if (context.container.read(appLifecycleProvider) ==
                AppLifecycleState.resumed) {
              final payload = TaskTargetSynchronization(data: current);
              context.container.read(taskEventRouterProvider).send(payload);
            }
            cache.cacheTarget(last);
            break;
          }
        } catch (_) {}

        await Future.delayed(const Duration(seconds: 10));
      }
    }
  }
}

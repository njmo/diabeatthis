import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../../core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/notifications/domain/events/temp_target_delivery_notification.dart';
import '../../../../../core/notifications/domain/events/temp_target_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../runtime/task_cancelled_exception.dart';
import '../../../../runtime/task_interrupted_exception.dart';
import '../../../../synchronization/synchronization_cache_controller.dart';
import '../../../base/runtime_context.dart';

final activityTempTargetMonitorProvider = Provider<ActivityTempTargetMonitor>(
  (_) => ActivityTempTargetMonitor(),
);

/// Target supervision runs inside activity monitor states and their wait scopes.
/// It has no independent scheduler lifetime or background loop.
class ActivityTempTargetMonitor {
  static const changedSignal = 'activity_monitor_targets_changed';
  TempTargetSendResult? _previousStopResult;

  Future<bool> isEnabled(RuntimeContext context) async {
    try {
      final prefs = await context.container.read(sharedPrefsProvider.future);
      await prefs.reload();
      return context.container.read(tempTargetServiceProvider).isEnabled(prefs);
    } catch (_) {
      // An unavailable preference store cannot authorize remote writes.
      return false;
    }
  }

  Future<void> reconcile(RuntimeContext context) async {
    if (!await isEnabled(context)) return;
    context.throwIfCancelled();
    try {
      final service = context.container.read(tempTargetServiceProvider);
      final notifications = context.container.read(
        notificationsControllerForegroundProvider,
      );
      final stopped = await service.stopFinishedActivityTarget();
      final message = switch (stopped) {
        TempTargetSendResult.sent => lang.notificationTempTargetStopSent,
        TempTargetSendResult.failed => lang.notificationTempTargetStopFailed,
        _ => null,
      };
      if (message != null &&
          (stopped != TempTargetSendResult.failed ||
              _previousStopResult != stopped)) {
        await notifications.show(
          TempTargetDeliveryNotification(message: message),
        );
      }
      _previousStopResult = stopped;
      Future<void> deliver(TempTargetNotificationEvent offer) async {
        try {
          await notifications.show(offer);
        } catch (_) {
          if (offer.requestId != null) service.deliveryFailed(offer.requestId!);
          rethrow;
        }
      }

      for (final offer in await service.pendingMealOffers()) {
        await deliver(offer);
      }
      final db = context.container.read(databaseProvider);
      final logs = await (db.select(
        db.activityLog,
      )..where((row) => row.endedAt.isNull())).get();
      for (final log in logs) {
        context.throwIfCancelled();
        final offer = await service.activityOffer(
          log.id,
          activeTarget: context.container
              .read(synchronizationCacheControllerProvider)
              .cache
              .targetCache,
        );
        if (offer != null) await deliver(offer);
      }
    } on TaskCancelledException {
      rethrow;
    } on TaskInterruptedException {
      rethrow;
    } catch (_) {
      context.log('Activity monitor temporary target reconciliation failed');
    }
  }

  /// Long state waits remain interruptible while supervising targets for all
  /// sessions. Database changes also wake cleanup for closed or deleted logs.
  Future<void> waitUntil(
    RuntimeContext context,
    DateTime? deadline, {
    int? activityLogId,
  }) async {
    final db = context.container.read(databaseProvider);
    final subscription = db
        .select(db.activityLog)
        .watch()
        .listen((_) => context.emitSignal(changedSignal));
    try {
      while (deadline == null || clock.now().isBefore(deadline)) {
        var closed = false;
        await context.withWaitScope((scope) async {
          final changed = scope.signalWait(changedSignal);
          changed.future.ignore();
          await reconcile(context);
          if (activityLogId != null) {
            final log = await db.activityDao.getActivityLogByIdOrNull(
              activityLogId,
            );
            closed = log == null || log.endedAt != null;
            if (closed) return;
          }
          final nextCheck = clock.now().add(const Duration(minutes: 1));
          final next = deadline != null && deadline.isBefore(nextCheck)
              ? deadline
              : nextCheck;
          await scope.any<void>([
            changed,
            scope.wallClockWaitUntilHandle(next),
          ]);
        });
        if (closed) return;
      }
    } finally {
      await subscription.cancel();
    }
  }
}

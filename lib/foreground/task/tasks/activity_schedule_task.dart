import 'dart:async';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../../common/events/data/notification/activity_schedule_response_event.dart';
import '../../../core/drift/database_impl.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../core/notifications/domain/events/activity_schedule_notification.dart';
import '../../../core/notifications/domain/events/temp_target_notification.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../features/activity/data/services/activity_schedule_service.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

/// Independent of the active session: an unanswered morning prompt cannot block
/// afternoon confirmations. Persisted occurrences survive process restarts.
class ActivityScheduleTask extends WorkflowTask {
  const ActivityScheduleTask();
  static const changedSignal = 'activity_schedule_changed';

  @override
  Future<void> run(RuntimeContext context) async {
    final db = context.container.read(databaseProvider);
    final service = context.container.read(activityScheduleServiceProvider);
    final inbox = context.openEventInbox<ActivityScheduleResponseEvent>();
    final subscriptions = <StreamSubscription<Object?>>[
      db
          .select(db.activityLog)
          .watch()
          .listen((_) => context.emitSignal(changedSignal)),
      db
          .select(db.activitySchedule)
          .watch()
          .listen((_) => context.emitSignal(changedSignal)),
      db
          .select(db.activityOccurrence)
          .watch()
          .listen((_) => context.emitSignal(changedSignal)),
    ];
    try {
      while (!context.isCancelled) {
        try {
          await context.withWaitScope((scope) async {
            final changed = scope.signalWait(changedSignal);
            final response = scope.eventWait<ActivityScheduleResponseEvent>();
            changed.future.ignore();
            response.future.ignore();
            for (final event in inbox.drain()) {
              await event.when(
                agree: (id) async {
                  await service.confirm(id);
                },
                skip: service.skip,
                empty: (_) async {},
              );
            }
            await service.refresh();
            final now = clock.now();
            final rows = await (db.select(
              db.activityOccurrence,
            )..orderBy([(r) => OrderingTerm.asc(r.actionAt)])).get();
            var next = DateTime(now.year, now.month, now.day + 1);
            final notifications = context.container.read(
              notificationsControllerForegroundProvider,
            );
            for (final row in rows) {
              if (row.startedAt <= now.millisecondsSinceEpoch ||
                  row.status == 'skipped' ||
                  row.status == 'missed') {
                continue;
              }
              if (row.status == 'pending') {
                final start = DateTime.fromMillisecondsSinceEpoch(
                  row.startedAt,
                );
                if (start.isBefore(next)) next = start;
                final actionAt = DateTime.fromMillisecondsSinceEpoch(
                  row.actionAt,
                );
                if (actionAt.isAfter(now)) {
                  if (actionAt.isBefore(next)) next = actionAt;
                } else if (row.confirmationMode == 'automatic') {
                  await service.confirm(row.id);
                } else if (row.askedAt == null) {
                  final activity = await db.activityDao.getActivityById(
                    row.activityId,
                  );
                  await notifications.show(
                    ActivityScheduleNotificationEvent(
                      occurrenceId: row.id,
                      activityName: activity.name,
                      startsAt: DateTime.fromMillisecondsSinceEpoch(
                        row.startedAt,
                      ),
                    ),
                  );
                  await (db.update(
                    db.activityOccurrence,
                  )..where((r) => r.id.equals(row.id))).write(
                    ActivityOccurrenceCompanion(
                      askedAt: Value(now.millisecondsSinceEpoch),
                    ),
                  );
                }
              } else if (row.status == 'planned' &&
                  row.targetRequestedAt == null &&
                  row.activityLogId != null) {
                // Previous-evening confirmation reserves the session immediately;
                // the target prompt belongs to the 90-minute preparation window.
                final targetAt = DateTime.fromMillisecondsSinceEpoch(
                  row.startedAt,
                ).subtract(const Duration(minutes: 90));
                if (targetAt.isAfter(now)) {
                  if (targetAt.isBefore(next)) next = targetAt;
                } else {
                  await notifications.show(
                    TempTargetNotificationEvent.activity(
                      entityId: row.activityLogId!,
                    ),
                  );
                  await (db.update(
                    db.activityOccurrence,
                  )..where((r) => r.id.equals(row.id))).write(
                    ActivityOccurrenceCompanion(
                      targetRequestedAt: Value(now.millisecondsSinceEpoch),
                    ),
                  );
                }
              }
            }
            await scope.any<void>([
              changed,
              response.map<void>((_) {}),
              scope.wallClockWaitUntilHandle(next),
            ]);
          });
        } on TaskCancelledException {
          rethrow;
        } catch (error) {
          context.log('Activity schedule reconciliation failed: $error');
          await context.withWaitScope(
            (scope) => scope.any<void>([
              scope.wallClockWaitUntilHandle(
                clock.now().add(const Duration(seconds: 30)),
              ),
            ]),
          );
        }
      }
    } finally {
      inbox.close();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
  }
}

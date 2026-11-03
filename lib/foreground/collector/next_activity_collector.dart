import 'dart:async';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/activity_event.dart';
import '../runtime/wait_handle.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class NextActivityCollector extends ForegroundCollector {
  StreamSubscription<List<ActivityLogData>>? _dbSubscription;
  StreamSubscription<List<ActivityData>>? _definitionSubscription;
  int? _lastDurationMinutes;
  bool _disposed = false;
  int? _lastActivityLogId;
  int? _lastActivityId;
  int? _lastStartedAt;
  int? _lastEndedAt;
  int? _startedActivityLogId;

  @override
  void start(CollectorContext context) {
    _dbSubscription = context.container
        .read(databaseProvider)
        .activityDao
        .getAllPendingActivityLogs()
        .listen((_) {
          context.emitSignal('next_activity_db_changed');
        });

    _definitionSubscription = context.container
        .read(databaseProvider)
        .activityDao
        .watchActivities()
        .listen((_) {
          context.emitSignal('next_activity_db_changed');
        });
    unawaited(runGuarded(() => _run(context)));
  }

  Future<void> _run(CollectorContext context) async {
    while (!_disposed) {
      final dbHandle = context.signalWait('next_activity_db_changed');
      try {
        final db = context.container.read(databaseProvider);
        final current = await db.activityDao.getNearestActivityLog();
        if (_disposed) return;

        if (current == null) {
          await _emitPreviousActivityEndIfNeeded(context);
          _clearLastActivity();
          await dbHandle.future;
          continue;
        }

        if (_lastActivityLogId != null && _lastActivityLogId != current.id) {
          await _emitPreviousActivityEndIfNeeded(context);
        }

        final activity = await db.activityDao.getActivityById(
          current.activityId,
        );
        final durationMinutes = await db.activityDao.getEffectiveDurationForLog(
          current.id,
          activity.durationMinutes,
        );
        if (_disposed) return;
        final changed =
            _lastActivityLogId != current.id ||
            _lastActivityId != current.activityId ||
            _lastStartedAt != current.startedAt ||
            _lastEndedAt != current.endedAt ||
            _lastDurationMinutes != durationMinutes;

        if (changed) {
          if (_lastActivityLogId != current.id) {
            _startedActivityLogId = null;
          }
          _lastActivityLogId = current.id;
          _lastActivityId = current.activityId;
          _lastStartedAt = current.startedAt;
          _lastEndedAt = current.endedAt;
          _lastDurationMinutes = durationMinutes;

          final startsAt = DateTime.fromMillisecondsSinceEpoch(
            current.startedAt,
          );

          logI("Nearest activity from database $current");
          logI(
            "Detected nearest activity change: ${current.id}, "
            "activity: ${current.activityId}, "
            "at: ${startsAt.toIso8601String()}",
          );

          context.emitEvent(
            NextActivityEvent(
              activityLogId: current.id,
              activityId: current.activityId,
              startsAt: startsAt,
            ),
          );
        }

        _emitActivityStartedIfNeeded(context, current);

        final startsAt = DateTime.fromMillisecondsSinceEpoch(current.startedAt);
        final now = DateTime.now();
        final waitDuration = startsAt.difference(now);

        if (waitDuration <= Duration.zero) {
          await _waitForDurationOrDbChange(
            context,
            const Duration(seconds: 1),
            dbHandle,
          );
          continue;
        }

        await _waitForDurationOrDbChange(context, waitDuration, dbHandle);
      } finally {
        await dbHandle.cancel();
      }
    }
  }

  Future<void> _waitForDurationOrDbChange(
    CollectorContext context,
    Duration duration,
    WaitHandle<void> dbHandle,
  ) async {
    final timeHandle = context.durationWait(duration);

    try {
      await Future.any([timeHandle.future, dbHandle.future]);
    } finally {
      await timeHandle.cancel();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _dbSubscription?.cancel();
    await _definitionSubscription?.cancel();
  }

  void _emitActivityStartedIfNeeded(
    CollectorContext context,
    ActivityLogData current,
  ) {
    if (_startedActivityLogId == current.id) return;

    final startsAt = DateTime.fromMillisecondsSinceEpoch(current.startedAt);
    if (startsAt.isAfter(DateTime.now())) return;

    _startedActivityLogId = current.id;
    context.emitEvent(
      ActivityEvent.started(
        activityLogId: current.id,
        activityId: current.activityId,
        startsAt: startsAt,
      ),
    );
  }

  Future<void> _emitPreviousActivityEndIfNeeded(
    CollectorContext context,
  ) async {
    final activityLogId = _lastActivityLogId;
    final activityId = _lastActivityId;
    final startedAt = _lastStartedAt;

    if (activityLogId == null || activityId == null || startedAt == null) {
      return;
    }

    final db = context.container.read(databaseProvider);
    final previous = await db.activityDao.getActivityLogByIdOrNull(
      activityLogId,
    );

    if (previous != null && previous.endedAt == null) return;

    final startsAt = DateTime.fromMillisecondsSinceEpoch(startedAt);
    final endedAt = previous?.endedAt;

    if (endedAt != null) {
      context.emitEvent(
        ActivityEvent.stopped(
          activityLogId: activityLogId,
          activityId: activityId,
          startsAt: startsAt,
          stoppedAt: DateTime.fromMillisecondsSinceEpoch(endedAt),
        ),
      );
      return;
    }

    if (startsAt.isAfter(DateTime.now())) {
      context.emitEvent(
        ActivityEvent.cancelled(
          activityLogId: activityLogId,
          activityId: activityId,
          startsAt: startsAt,
        ),
      );
      return;
    }

    context.emitEvent(
      ActivityEvent.stopped(
        activityLogId: activityLogId,
        activityId: activityId,
        startsAt: startsAt,
        stoppedAt: DateTime.now(),
      ),
    );
  }

  void _clearLastActivity() {
    _lastActivityLogId = null;
    _lastActivityId = null;
    _lastStartedAt = null;
    _lastEndedAt = null;
    _lastDurationMinutes = null;
    _startedActivityLogId = null;
  }
}

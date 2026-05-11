import 'dart:async';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/activity_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class NextActivityCollector extends ForegroundCollector {
  StreamSubscription<List<ActivityLogData>>? _dbSubscription;
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

    unawaited(_run(context));
  }

  Future<void> _run(CollectorContext context) async {
    while (!_disposed) {
      final db = context.container.read(databaseProvider);
      final current = await db.activityDao.getNearestActivityLog();

      if (current == null) {
        await _emitPreviousActivityEndIfNeeded(context);
        _clearLastActivity();
        await context.waitForSignal('next_activity_db_changed');
        continue;
      }

      if (_lastActivityLogId != null && _lastActivityLogId != current.id) {
        await _emitPreviousActivityEndIfNeeded(context);
      }

      final changed =
          _lastActivityLogId != current.id ||
          _lastActivityId != current.activityId ||
          _lastStartedAt != current.startedAt ||
          _lastEndedAt != current.endedAt;

      if (changed) {
        if (_lastActivityLogId != current.id) {
          _startedActivityLogId = null;
        }
        _lastActivityLogId = current.id;
        _lastActivityId = current.activityId;
        _lastStartedAt = current.startedAt;
        _lastEndedAt = current.endedAt;

        final startsAt = DateTime.fromMillisecondsSinceEpoch(current.startedAt);

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
        await _waitForDurationOrDbChange(context, const Duration(seconds: 1));
        continue;
      }

      await _waitForDurationOrDbChange(context, waitDuration);
    }
  }

  Future<void> _waitForDurationOrDbChange(
    CollectorContext context,
    Duration duration,
  ) async {
    final timeHandle = context.durationWait(duration);
    final dbHandle = context.signalWait('next_activity_db_changed');

    try {
      await Future.any([timeHandle.future, dbHandle.future]);
    } finally {
      await timeHandle.cancel();
      await dbHandle.cancel();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _dbSubscription?.cancel();
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
    _startedActivityLogId = null;
  }
}

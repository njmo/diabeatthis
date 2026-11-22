import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';

import '../../common/meal_advisor/remote/scheduled_meal_decision_journal.dart';
import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_event.dart';
import '../runtime/wait_handle.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class NextMealCollector extends ForegroundCollector {
  StreamSubscription<List<MealData>>? _dbSubscription;
  StreamSubscription<List<FamilyMealDecisionReceipt>>? _receiptSubscription;
  Future<void> _pendingReceipts = Future.value();
  final Set<String> _seenReceipts = {};
  bool _disposed = false;
  final Completer<void> _disposeSignal = Completer<void>();
  Future<void>? _running;
  List<MealData>? _latestMeals;
  WaitHandle<void>? _announcementDelay;
  int? _lastMealId;
  int? _lastPlannedAt;
  String? _lastStatus;

  @override
  void start(CollectorContext context) {
    final db = context.container.read(databaseProvider);
    _receiptSubscription = db
        .select(db.familyMealDecisionReceipts)
        .watch()
        .listen((rows) {
          _pendingReceipts = _pendingReceipts
              .then((_) => _wakeForReceipts(context, rows))
              .catchError((Object error, StackTrace stackTrace) {
                logE(
                  'Could not check scheduled meal receipts',
                  error: error,
                  stackTrace: stackTrace,
                );
              });
        });
    _dbSubscription = context.container
        .read(databaseProvider)
        .mealDao
        .watchFuturePlannedMeals()
        .listen((rows) {
          _latestMeals = rows;
          context.emitSignal('next_meal_db_changed');
        });

    _running = runGuarded(() => _run(context));
  }

  Future<void> _wakeForReceipts(
    CollectorContext context,
    List<FamilyMealDecisionReceipt> receipts,
  ) async {
    final db = context.container.read(databaseProvider);
    for (final receipt in receipts) {
      if (_disposed) return;
      if (!_seenReceipts.add(receipt.requestId)) continue;
      context.emitSignal('scheduled_meal_receipt:${receipt.mealId}');
      Map<String, dynamic> outcome;
      try {
        outcome = jsonDecode(receipt.outcomeJson) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final plannedMillis = outcome['plannedAt'];
      if (outcome['source'] != 'caregiver' ||
          outcome['scheduled'] != true ||
          outcome['decision'] != 'insulinThenWait' ||
          plannedMillis is! int) {
        continue;
      }
      final now = clock.now();
      final plannedAt = DateTime.fromMillisecondsSinceEpoch(plannedMillis);
      if (plannedAt.isAfter(now) ||
          !now.isBefore(plannedAt.add(scheduledMealDecisionRecoveryWindow))) {
        continue;
      }
      final journal = await ScheduledMealDecisionJournal(
        db,
      ).load(receipt.mealId, plannedAt);
      if (_disposed ||
          journal?.uid != receipt.ownerUid ||
          journal?.requestId != receipt.requestId ||
          journal?.handled != true) {
        continue;
      }
      final candidate = await db.mealDao.getMealForMonitoring(now);
      if (_disposed ||
          candidate?.id != receipt.mealId ||
          candidate?.status != 'planned' ||
          candidate?.plannedAt != plannedMillis) {
        continue;
      }
      context.emitEvent(NextMealEvent(receipt.mealId, plannedAt));
    }
  }

  Future<void> _run(CollectorContext context) async {
    while (!_disposed) {
      // Subscribe before the query so a commit during the read cannot be lost.
      final dbHandle = context.signalWait('next_meal_db_changed');
      try {
        final meals = _latestMeals;
        if (meals == null) {
          await Future.any([dbHandle.future, _disposeSignal.future]);
          continue;
        }
        final now = clock.now();
        MealData? current;
        for (final meal in meals) {
          final timestamp = meal.plannedAt;
          if (meal.status == 'planned' &&
              timestamp != null &&
              timestamp > now.millisecondsSinceEpoch) {
            current = meal;
            break;
          }
        }
        if (current == null) {
          context.emitEvent(PlannedMealsClearedEvent());
          _lastMealId = null;
          _lastPlannedAt = null;
          _lastStatus = null;
          await Future.any([dbHandle.future, _disposeSignal.future]);
          continue;
        }

        final changed =
            _lastMealId != current.id ||
            _lastPlannedAt != current.plannedAt ||
            _lastStatus != current.status;

        if (changed) {
          // New candidates settle before announcement so a persisted meal
          // status transition can take ownership of its active workflow.
          // Database changes cancel this delay; removals are never debounced.
          late final bool settled;
          final settleHandle = WaitHandle.delay(const Duration(seconds: 1));
          _announcementDelay = settleHandle;
          try {
            settled = await Future.any<bool>([
              settleHandle.future.then((_) => true),
              dbHandle.future.then((_) => false),
              _disposeSignal.future.then((_) => false),
            ]);
          } finally {
            await settleHandle.cancel();
            if (identical(_announcementDelay, settleHandle)) {
              _announcementDelay = null;
            }
          }
          if (_disposed) return;
          if (!settled) continue;
          final latest = await context.container
              .read(databaseProvider)
              .mealDao
              .getNearestMeal();
          if (_disposed) return;
          if (latest == null ||
              latest.id != current.id ||
              latest.plannedAt != current.plannedAt ||
              latest.status != current.status) {
            continue;
          }
          _lastMealId = current.id;
          _lastPlannedAt = current.plannedAt;
          _lastStatus = current.status;

          final plannedAt = DateTime.fromMillisecondsSinceEpoch(
            current.plannedAt!,
          );

          logI("Nearest meal from database $current");
          logI(
            "Detected nearest meal change: ${current.id}, "
            "status: ${current.status}, "
            "at: ${plannedAt.toIso8601String()}",
          );

          context.emitEvent(NextMealEvent(current.id, plannedAt));
        }

        final plannedAt = DateTime.fromMillisecondsSinceEpoch(
          current.plannedAt!,
        );
        final waitDuration = plannedAt.difference(clock.now());

        if (waitDuration <= Duration.zero) {
          // Re-evaluate the next candidate if its time passed during validation.
          continue;
        }

        final timeHandle = context.durationWait(waitDuration);
        try {
          await Future.any([
            timeHandle.future,
            dbHandle.future,
            _disposeSignal.future,
          ]);
        } finally {
          await timeHandle.cancel();
        }
      } finally {
        await dbHandle.cancel();
      }
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    if (!_disposeSignal.isCompleted) _disposeSignal.complete();
    await _dbSubscription?.cancel();
    await _receiptSubscription?.cancel();
    await _pendingReceipts;
    await _announcementDelay?.cancel();
    await _running;
  }
}

import 'dart:async';

import 'package:clock/clock.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_event.dart';
import '../runtime/wait_handle.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class NextMealCollector extends ForegroundCollector {
  StreamSubscription<List<MealData>>? _dbSubscription;
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
          if (meal.status == 'planned' &&
              meal.plannedAt > now.millisecondsSinceEpoch) {
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
            current.plannedAt,
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
          current.plannedAt,
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
    await _announcementDelay?.cancel();
    await _running;
  }
}

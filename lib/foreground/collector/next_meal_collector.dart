import 'dart:async';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class NextMealCollector extends ForegroundCollector {
  StreamSubscription<List<MealData>>? _dbSubscription;
  bool _disposed = false;
  int? _lastMealId;
  int? _lastPlannedAt;
  String? _lastStatus;

  @override
  void start(CollectorContext context) {
    _dbSubscription = context.container
        .read(databaseProvider)
        .mealDao
        .getAllMealForToday()
        .listen((_) {
      context.emitSignal('next_meal_db_changed');
    });

    unawaited(_run(context));
  }

  Future<void> _run(CollectorContext context) async {
    while (!_disposed) {
      final db = context.container.read(databaseProvider);
      final current = await db.mealDao.getNearestMeal();

      if (current == null) {
        _lastMealId = null;
        _lastPlannedAt = null;
        _lastStatus = null;
        await context.waitForSignal('next_meal_db_changed');
        continue;
      }

      final changed =
          _lastMealId != current.id ||
              _lastPlannedAt != current.plannedAt ||
              _lastStatus != current.status;

      if (changed) {
        _lastMealId = current.id;
        _lastPlannedAt = current.plannedAt;
        _lastStatus = current.status;

        final plannedAt = DateTime.fromMillisecondsSinceEpoch(current.plannedAt);

        logI("Nearest meal from database $current");
        logI(
          "Detected nearest meal change: ${current.id}, "
              "status: ${current.status}, "
              "at: ${plannedAt.toIso8601String()}",
        );

        context.emitEvent(NextMealEvent(current.id, plannedAt));
      }

      final plannedAt = DateTime.fromMillisecondsSinceEpoch(current.plannedAt);
      final now = DateTime.now();
      final waitDuration = plannedAt.difference(now);

      if (waitDuration <= Duration.zero) {
        await context.waitForDuration(const Duration(seconds: 1));
        continue;
      }

      final timeHandle = context.durationWait(waitDuration);
      final dbHandle = context.signalWait('next_meal_db_changed');

      try {
        await Future.any([
          timeHandle.future,
          dbHandle.future,
        ]);
      } finally {
        await timeHandle.cancel();
        await dbHandle.cancel();
      }
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _dbSubscription?.cancel();
  }
}
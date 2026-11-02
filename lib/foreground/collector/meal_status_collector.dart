import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/model/meal_status_flow.dart';
import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_status_changed_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchLatestMealStatusHistoryProvider =
    StreamProvider.autoDispose<MealStatusHistoryData?>((ref) {
      final db = ref.read(databaseProvider);

      final query = db.select(db.mealStatusHistory)
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..where((t) => t.status.isNotValue('planned'))
        ..limit(1);

      return query.watchSingleOrNull();
    });

class MealStatusCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;
  Future<void> _pending = Future.value();
  bool _initialStateRecovered = false;
  bool _disposed = false;

  MealStatusCollector();

  @override
  Future<void> dispose() async {
    _disposed = true;
    _subscription.close();
  }

  @override
  void start(CollectorContext context) {
    _subscription = context.container
        .listen<AsyncValue<MealStatusHistoryData?>>(
          watchLatestMealStatusHistoryProvider,
          (previous, next) {
            next.whenData((data) {
              _pending = _pending
                  .then((_) => _publish(context, data))
                  .catchError((Object error, StackTrace stackTrace) {
                    logE(
                      'Could not publish meal state',
                      error: error,
                      stackTrace: stackTrace,
                    );
                  });
            });
          },
          fireImmediately: true,
        );
  }

  Future<void> _publish(
    CollectorContext context,
    MealStatusHistoryData? data,
  ) async {
    if (_disposed) return;
    final db = context.container.read(databaseProvider);
    if (!_initialStateRecovered) {
      // The latest history entry may belong to a different, completed meal.
      // Restore the active workflow from its current row before live changes.
      final active =
          await (db.select(db.meal)
                ..where((row) => row.purpose.equals('meal'))
                ..where(
                  (row) => row.status.isIn(
                    mealStatusesBlockingAnotherMealActivation.toList(
                      growable: false,
                    ),
                  ),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.plannedAt)])
                ..limit(1))
              .getSingleOrNull();
      if (_disposed) return;
      _initialStateRecovered = true;
      if (active != null) {
        _emit(context, active.id, active.status);
        if (active.id == data?.mealId && active.status == data?.status) return;
      }
    }
    if (data == null) return;
    final current = await db.mealDao.getMealById(data.mealId);
    if (_disposed ||
        current?.purpose != 'meal' ||
        current?.status != data.status) {
      return;
    }
    _emit(context, data.mealId, data.status);
  }

  void _emit(CollectorContext context, int mealId, String status) {
    final event = MealStatusChangedEvent.fromJson({
      'kind': status,
      'mealId': mealId,
    });
    logI('Emitting meal $mealId state $status');
    context.emitEvent(event);
  }
}

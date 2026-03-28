import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  MealStatusCollector();

  @override
  Future<void> dispose() async {
    _subscription.close();
  }

  @override
  void start(CollectorContext context) {
    _subscription = context.container.listen<AsyncValue<MealStatusHistoryData?>>(
      watchLatestMealStatusHistoryProvider,
      (previous, next) {
        next.whenData((data) {
          logI("Receiver from database $data");
          if (data == null) return;
          if (['eaten', 'eaten-bolused', 'skipped'].contains(data.status) &&
              data.createdAt < clock.now().millisecondsSinceEpoch) {
            logI("This data is not meaningful if it is older than now");
            return;
          }
          logI(
            "Detected change in from database for meal ${data.mealId} status : ${data.status}",
          );
          final event = MealStatusChangedEvent.fromJson({
            'kind': data.status,
            'mealId': data.mealId,
          });
          logI("Emitting event ${event.runtimeType}");
          context.emitEvent(event);
        });
      },
      fireImmediately: true,
    );
  }
}

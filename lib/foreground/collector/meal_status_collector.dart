import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_status_changed_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchLatestMealStatusHistoryProvider =
    StreamProvider<MealStatusHistoryData?>((ref) {
      final db = ref.read(databaseProvider);

      final query = db.select(db.mealStatusHistory)
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..limit(1);

      return query.watchSingleOrNull();
    });

class MealStatusCollector extends ForegroundCollector {

  late final ProviderSubscription _subscription;

  MealStatusCollector();

  @override
  Future<void> dispose() async{
    _subscription.close();
  }

  @override
  void start(CollectorContext context) {
    _subscription = context.container.listen<AsyncValue<MealStatusHistoryData?>>(
      watchLatestMealStatusHistoryProvider,
          (previous, next) {
        next.whenData((data) {
          print("Receiver from database $data");
          if (data == null) return;
          print("Detected change in from database for meal ${data.mealId} status : ${data.status}");
          if (data.status != 'planned') {
            final event = MealStatusChangedEvent.fromJson({'kind' : data.status, 'mealId' : data.mealId});
            print("Emitting event ${event.runtimeType}");
            context.emitEvent(event);
          }
        });
      },
      fireImmediately: true,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_event.dart';
import '../runtime/event_dispatcher.dart';
import '../runtime/workflow_scheduler.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchNearestMealStatusProvider =
StreamProvider<MealData?>((ref) {
  final db = ref.read(databaseProvider);

  return db.mealDao.getNearestMeal();
});

class NextMealCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;

  NextMealCollector();

  @override
  void start(CollectorContext context){
    _subscription = context.container.listen<AsyncValue<MealData?>>(
      watchNearestMealStatusProvider,
          (previous, next) {
        next.whenData((data) {
          print("Nearest meal from database $data");
          if (data == null) return;
          print("Detected change in from database for nearest meal ${data.id} status : ${data.status} at ${DateTime.fromMillisecondsSinceEpoch(data.plannedAt).toIso8601String()}");
          context.emitEvent(NextMealEvent(data.id, DateTime.fromMillisecondsSinceEpoch(data.plannedAt)));
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Future<void> dispose() async {
    _subscription.close();
  }
}

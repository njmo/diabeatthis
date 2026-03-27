import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchNearestMealStatusProvider = StreamProvider.autoDispose<MealData?>((
  ref,
) {
  final db = ref.read(databaseProvider);

  return db.mealDao.getNearestMealStream();
});

class NextMealCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;

  NextMealCollector();

  @override
  void start(CollectorContext context) {
    _subscription = context.container.listen<AsyncValue<MealData?>>(
      watchNearestMealStatusProvider,
      (previous, next) {
        final prevData = previous?.value;
        final nextData = next.value;

        final changed =
            prevData?.id != nextData?.id ||
            prevData?.plannedAt != nextData?.plannedAt ||
            prevData?.status != nextData?.status;

        if (!changed || nextData == null) return;

        final plannedAt = DateTime.fromMillisecondsSinceEpoch(
          nextData.plannedAt,
        );

        logI("Nearest meal from database $nextData");
        logI(
          "Detected nearest meal change: ${nextData.id}, "
          "status: ${nextData.status}, "
          "at: ${plannedAt.toIso8601String()}",
        );

        context.emitEvent(NextMealEvent(nextData.id, plannedAt));
      },
      fireImmediately: true,
    );
  }

  @override
  Future<void> dispose() async {
    _subscription.close();
  }
}

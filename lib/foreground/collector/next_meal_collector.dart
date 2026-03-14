import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_event.dart';
import '../runtime/event_dispatcher.dart';
import 'foreground_collector.dart';

final watchNearestMealStatusProvider =
StreamProvider<MealData?>((ref) {
  final db = ref.read(databaseProvider);

  return db.mealDao.getNearestMeal();
});

class NextMealCollector extends ForegroundCollector {
  final ProviderContainer _container;

  late final ProviderSubscription _subscription;

  bool _changeDetected = false;
  MealData? _history;

  NextMealCollector(this._container) {
    _subscription = _container.listen<AsyncValue<MealData?>>(
      watchNearestMealStatusProvider,
          (previous, next) {
        next.whenData((data) {
          print("Nearest meal from database $data");
          if (data == null) return;
          print("Detected change in from database for nearest meal ${data.id} status : ${data.status} at ${DateTime.fromMillisecondsSinceEpoch(data.plannedAt).toIso8601String()}");

          _changeDetected = true;
          _history = data;
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Future<void> collect(EventDispatcher dispatcher) async {
    if (!_changeDetected) return;

    _changeDetected = false;

    final history = _history;
    if (history == null) return;

    print('Detected new next meal $history');
    dispatcher.dispatch(NextMealEvent(history.id));
  }

  void dispose() {
    _subscription.close();
  }
}

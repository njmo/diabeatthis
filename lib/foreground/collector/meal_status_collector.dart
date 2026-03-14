import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';
import '../event/internal/meal_status_changed_event.dart';
import '../runtime/event_dispatcher.dart';
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
  final ProviderContainer _container;

  late final ProviderSubscription _subscription;

  bool _changeDetected = false;
  MealStatusHistoryData? _history;

  MealStatusCollector(this._container) {
    _subscription = _container.listen<AsyncValue<MealStatusHistoryData?>>(
      watchLatestMealStatusHistoryProvider,
      (previous, next) {
        next.whenData((data) {
          print("Receiver from database $data");
          if (data == null) return;
          print("Detected change in from database for meal ${data.mealId} status : ${data.status}");

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

    print('Collecting meal status history for ${history.mealId} status : ${history.status}');
    final event = MealStatusChangedEvent.fromJson({'kind' : history.status, 'mealId' : history.mealId});
    dispatcher.dispatch(event);
  }

  void dispose() {
    _subscription.close();
  }
}

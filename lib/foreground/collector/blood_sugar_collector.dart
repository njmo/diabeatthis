import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../core/data/provider/nightscout_repository_provider.dart';
import '../../core/domain/model/glucose.dart';
import '../../core/logger/logger.dart';
import '../event/internal/data_available_event.dart';
import '../providers/blood_sugar_value_provider.dart';
import '../providers/task_event_router_provider.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchNearestBloodSugarProvider = StreamProvider.autoDispose<Glucose?>((
  ref,
) async* {
  Log.i("watchNearestBloodSugarProvider", "start");
  var disposed = false;

  ref.onDispose(() {
    disposed = true;
  });

  int? lastValue;
  DateTime? lastReadingDate;

  // build history
  var glucoseReadings = await ref.read(glucoseWithLimitProvider(2).future);
  if (glucoseReadings.length == 2) {
    lastValue = glucoseReadings[1].sgv;
    lastReadingDate = glucoseReadings[1].date;
  }

  while (!disposed) {
    if (glucoseReadings.isEmpty) {
      glucoseReadings = await ref.read(glucoseWithLimitProvider(1).future);
      await Future.delayed(Duration(seconds: 10));
      continue;
    }

    final glucose = glucoseReadings.first;
    final now = clock.now();
    final readingAge = now.difference(glucose.date);
    final spaceBetweenReadings = lastReadingDate == null
        ? Duration.zero
        : glucose.date.difference(lastReadingDate);

    // fill tick value only when reading is fresh and 2 consecutive readings are available
    if (spaceBetweenReadings.inMinutes <= 6 &&
        readingAge < Duration(minutes: 10) &&
        lastValue != null) {
      yield glucose.copyWith(tick: glucose.sgv - lastValue);
    }
    lastValue = glucose.sgv;
    lastReadingDate = glucose.date;

    // sleep until next reading available
    if (readingAge < Duration(minutes: 5)) {
      final remainingDurationToFife = Duration(minutes: 5) - readingAge;
      await Future.delayed(remainingDurationToFife);
    }

    // read until new glucose is available
    while (glucoseReadings.isNotEmpty &&
        glucoseReadings.first.date == lastReadingDate) {
      glucoseReadings = await ref.read(glucoseWithLimitProvider(1).future);
      await Future.delayed(Duration(seconds: 10));
    }
  }
});

class BloodSugarCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;

  @override
  void start(CollectorContext context) {
    logI("Starting blood sugar collector");
    _subscription = context.container.listen<AsyncValue<Glucose?>>(
      watchNearestBloodSugarProvider,
      (previous, next) {
        next.whenData((data) {
          logI("Glucose reading available $data");
          if (data == null) return;
          logI(
            "Detected change in glucose reading ${data.id} at ${data.date.toIso8601String()} with value ${data.sgv} and tick ${data.tick}",
          );
          context.emitEvent(DataAvailableEvent<Glucose>(data));
          final payload = TaskGlucoseSynchronization(data: data);
          context.container.read(taskEventRouterProvider).send(payload);

          context.container.read(bloodSugarValueProvider.notifier).update(data);
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

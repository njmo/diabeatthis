import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/nightscout_repository_provider.dart';
import '../../core/domain/model/glucose.dart';
import '../event/internal/data_available_event.dart';
import '../providers/blood_sugar_value_provider.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchNearestBloodSugarProvider = StreamProvider<Glucose?>((ref) async* {
  int? lastID;
  int? lastValue;
  DateTime? lastReadingDate;

  // build history
  var glucoseReadings = await ref.read(glucoseWithLimitProvider(2).future);
  if (glucoseReadings.length == 2) {
    lastID = glucoseReadings[1].id;
    lastValue = glucoseReadings[1].sgv;
    lastReadingDate = glucoseReadings[1].date;
  }

  while (true) {
    if (glucoseReadings.isEmpty) {
      glucoseReadings = await ref.read(glucoseWithLimitProvider(1).future);
      await Future.delayed(Duration(seconds: 10));
      continue;
    }

    final glucose = glucoseReadings.first;
    final now = DateTime.now();
    final readingAge = now.difference(glucose.date);
    final readingAgeInMinutes = readingAge.inMinutes;
    final spaceBetweenReadings = lastReadingDate == null
        ? Duration.zero
        : glucose.date.difference(lastReadingDate);

    // fill tick value only when reading is fresh and 2 consecutive readings are available
    if (spaceBetweenReadings.inMinutes <= 6 &&
        readingAgeInMinutes < 10 &&
        lastValue != null) {
      yield glucose.copyWith(tick: glucose.sgv - lastValue);
    }
    lastID = glucose.id;
    lastValue = glucose.sgv;
    lastReadingDate = glucose.date;

    // sleep until next reading available
    print("waiting $readingAgeInMinutes");
    if (readingAgeInMinutes < 5) {
      final remainingDurationToFife = Duration(minutes: 5) - readingAge;
      await Future.delayed(remainingDurationToFife);
    }

    // read until new glucose is available
    while (glucoseReadings.isNotEmpty && lastID == glucoseReadings.first.id) {
      glucoseReadings = await ref.read(glucoseWithLimitProvider(1).future);
      await Future.delayed(Duration(seconds: 10));
    }
  }
});

class BloodSugarCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;

  @override
  void start(CollectorContext context) {
    _subscription = context.container.listen<AsyncValue<Glucose?>>(
      watchNearestBloodSugarProvider,
      (previous, next) {
        next.whenData((data) {
          print("Glucose reading available $data");
          if (data == null) return;
          print(
            "Detected change in glucose reading ${data.id} at ${data.date.toIso8601String()} with value ${data.sgv} and tick ${data.tick}",
          );
          context.emitEvent(
            DataAvailableEvent<Glucose>(data),
          );
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

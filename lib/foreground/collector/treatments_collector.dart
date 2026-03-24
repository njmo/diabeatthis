import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/nightscout_repository_provider.dart';
import '../../core/domain/model/treatment_base.dart';
import '../event/internal/treatment_available_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchNewTreatmentsProvider = StreamProvider<Treatment?>((ref) async* {
  var lastReadingDate = clock.now();

  while (true) {
    final treatments = await ref.read(treatmentsAfterProvider(lastReadingDate).future);
    if (treatments.isEmpty) {
      await Future.delayed(const Duration(seconds: 30));
      continue;
    }

    for(final treatment in treatments.reversed) {
      yield treatment;
    }

    lastReadingDate = treatments.first.dateHappened ?? clock.now();
    lastReadingDate = lastReadingDate.add(Duration(seconds: 5));
  }
});

class TreatmentsCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;

  @override
  void start(CollectorContext context) {
    _subscription = context.container.listen<AsyncValue<Treatment?>>(
      watchNewTreatmentsProvider,
          (previous, next) {
        next.whenData((data) {
          logI("New treatment reading available $data");
          if (data == null) return;
          logI(
            "Detected change in treatment reading ${data.id} at ${data.dateHappened?.toIso8601String()}",
          );
          context.emitEvent(
            TreatmentAvailableEvent(data),
          );
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

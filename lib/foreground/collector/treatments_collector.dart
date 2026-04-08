import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/nightscout_repository_provider.dart';
import '../../core/domain/model/correction_bolus.dart';
import '../../core/domain/model/extended_carb.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/meal.dart';
import '../../core/domain/model/temporary_target.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';
import '../../core/logger/logger.dart';
import '../event/internal/treatment_available_event.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

final watchNewTreatmentsProvider = StreamProvider.autoDispose<Treatment?>((
  ref,
) async* {
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
  });

  var lastReadingDate = clock.now();

  // check for already active temp target
  final target = await ref.read(temporaryTargetProvider.future);
  if(target.createdAt.add(Duration(minutes: target.duration)).isAfter(lastReadingDate)) {
    Log.i("watchNewTreatmentsProvider", "Found active temp target");
    yield target;
  }

  while (!disposed) {
    var treatments = List.empty();
    try {
      treatments = await ref.read(
        treatmentsAfterProvider(lastReadingDate).future,
      );
    } catch (e) {
      Log.i("watchNewTreatmentsProvider", "Error fetching treatments $e");
    }

    if (treatments.isEmpty) {
      await Future.delayed(const Duration(seconds: 30));
      continue;
    }

    for (final treatment in treatments.reversed) {
      yield treatment;
    }

    lastReadingDate = treatments.first.createdAt ?? clock.now();
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
            "Detected change in treatment reading ${data.id} at ${data.createdAt?.toIso8601String()}",
          );

          switch (data) {
            case Meal():
              logI("Meal treatment");
              context.emitEvent(TreatmentAvailableEvent<Meal>(data));
              break;
            case CorrectionBolus():
              logI("Correction bolus treatment");
              context.emitEvent(TreatmentAvailableEvent<CorrectionBolus>(data));
              break;
            case Treat():
              logI("Treat treatment");
              context.emitEvent(TreatmentAvailableEvent<Treat>(data));
              break;
            case ExtendedCarb():
              logI("Extended carb treatment");
              context.emitEvent(TreatmentAvailableEvent<ExtendedCarb>(data));
              break;
            case ManualBolus():
              logI("Manual bolus treatment");
              context.emitEvent(TreatmentAvailableEvent<ManualBolus>(data));
              break;
            case TemporaryTarget():
              logI("Temporary target treatment");
              context.emitEvent(TreatmentAvailableEvent<TemporaryTarget>(data));
              break;
            default:
              logI("Unknown treatment");
          }
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

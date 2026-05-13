import 'dart:async';

import 'package:clock/clock.dart';

import '../../core/data_sources/providers/source_repository_providers.dart';
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

class TreatmentsCollector extends ForegroundCollector with Logging {
  bool _disposed = false;
  Future<void>? _runner;

  @override
  void start(CollectorContext context) {
    logI("Starting treatments collector");
    _runner = _run(context);
  }

  Future<void> _run(CollectorContext context) async {
    var lastReadingDate = clock.now();

    try {
      final target = await _fetchLastTemporaryTarget(context);
      if (target.createdAt
          .add(Duration(minutes: target.duration))
          .isAfter(lastReadingDate)) {
        logI("Found active temp target");
        _handleTreatment(context, target);
      }
    } catch (e, st) {
      logW("Initial temp target read failed: $e\n$st");
    }

    while (!_disposed) {
      var treatments = const <Treatment>[];

      try {
        treatments = await _fetchTreatmentsAfter(context, lastReadingDate);
      } catch (e, st) {
        logW("Error fetching treatments $e\n$st");
      }

      if (treatments.isEmpty) {
        await context.durationWait(const Duration(minutes: 1)).future;
        continue;
      }

      for (final treatment in treatments.reversed) {
        _handleTreatment(context, treatment);
      }

      lastReadingDate = treatments.first.createdAt ?? clock.now();
      lastReadingDate = lastReadingDate.add(const Duration(seconds: 5));
    }
  }

  Future<TemporaryTarget> _fetchLastTemporaryTarget(
    CollectorContext context,
  ) async {
    final repository = await context.container.read(
      treatmentSourceRepositoryProvider.future,
    );
    return repository.fetchLastTemporaryTarget();
  }

  Future<List<Treatment>> _fetchTreatmentsAfter(
    CollectorContext context,
    DateTime after,
  ) async {
    final repository = await context.container.read(
      treatmentSourceRepositoryProvider.future,
    );
    return repository.fetchTreatmentsAfter(after);
  }

  void _handleTreatment(CollectorContext context, Treatment data) {
    logI("New treatment reading available $data");
    logI(
      "Detected change in treatment reading ${data.id} at "
      "${data.createdAt?.toIso8601String()}",
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
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _runner;
  }
}

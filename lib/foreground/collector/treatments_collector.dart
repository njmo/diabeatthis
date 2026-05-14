import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/correction_bolus.dart';
import '../../core/domain/model/extended_carb.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/temporary_target.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';
import '../../core/logger/logger.dart';
import '../alarm/foreground_alarm_bridge.dart';
import '../event/internal/treatment_available_event.dart';
import '../providers/task_event_router_provider.dart';
import '../synchronization/synchronization_cache_controller.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class TreatmentsCollector extends ForegroundCollector with Logging {
  static const _pollInterval = Duration(minutes: 1);

  bool _disposed = false;
  Future<void>? _runner;

  @override
  void start(CollectorContext context) {
    logI("Starting treatments collector");
    _runner = _run(context);
  }

  Future<void> _run(CollectorContext context) async {
    while (!_disposed) {
      var treatments = const <Treatment>[];

      try {
        treatments = await _pollTreatments(context);
      } catch (e, st) {
        logW("Error fetching treatments $e\n$st");
      }

      for (final treatment in treatments.reversed) {
        try {
          _handleTreatment(context, treatment);
        } catch (e, st) {
          logW("Error handling treatment $treatment: $e\n$st");
        }
      }

      await _waitForNextPoll(context);
    }
  }

  Future<List<Treatment>> _pollTreatments(CollectorContext context) async {
    final repository = await context.container.read(
      treatmentsSourceRepositoryProvider.future,
    );
    return repository.pollTreatments();
  }

  Future<void> _waitForNextPoll(CollectorContext context) async {
    final nextPollAt = clock.now().add(_pollInterval);
    await ForegroundAlarmBridge.scheduleCollectTick(nextPollAt);
    await context.waitForDuration(_pollInterval);
  }

  void _handleTreatment(CollectorContext context, Treatment data) {
    logI("New treatment reading available $data");
    logI(
      "Detected change in treatment reading at "
      "${data.createdAt?.toIso8601String()}",
    );

    switch (data) {
      case BolusWizard():
        logI("Bolus wizard treatment");
        context.emitEvent(TreatmentAvailableEvent<BolusWizard>(data));
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
        _syncTemporaryTarget(context, data);
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

  void _syncTemporaryTarget(CollectorContext context, TemporaryTarget target) {
    final cache = context.container.read(
      synchronizationCacheControllerProvider,
    );
    cache.cacheTarget(target);

    if (context.container.read(appLifecycleProvider) !=
        AppLifecycleState.resumed) {
      return;
    }

    final payload = TaskTargetSynchronization(data: target);
    context.container.read(taskEventRouterProvider).send(payload);
  }
}

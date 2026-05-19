import 'dart:async';

import 'package:clock/clock.dart';

import '../../core/data_sources/config/data_source_config_provider.dart';
import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/treatment_base.dart';
import '../../core/logger/logger.dart';
import '../alarm/foreground_alarm_bridge.dart';
import '../event/internal/treatment_event_dispatcher.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class TreatmentsCollector extends ForegroundCollector with Logging {
  static const _pollInterval = Duration(minutes: 1);

  final _treatmentEventDispatcher = TreatmentEventDispatcher();
  bool _disposed = false;
  Future<void>? _runner;

  @override
  void start(CollectorContext context) {
    logI("Starting treatments collector");
    _runner = _run(context);
  }

  Future<void> _run(CollectorContext context) async {
    final config = await context.container.read(
      dataSourceConfigProvider.future,
    );
    final treatmentsSource = config.treatmentsSource;
    if (treatmentsSource.isPushBased) {
      logI(
        'Treatments collector is idle because ${treatmentsSource.storageValue} '
        'is push-based',
      );
      return;
    }

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
    _treatmentEventDispatcher.dispatch(
      container: context.container,
      emitEvent: context.emitEvent,
      treatment: data,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _runner;
  }
}

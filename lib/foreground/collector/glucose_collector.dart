import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/glucose.dart';
import '../alarm/foreground_alarm_bridge.dart';
import '../event/internal/data_available_event.dart';
import '../providers/blood_sugar_value_provider.dart';
import '../providers/task_event_router_provider.dart';
import '../synchronization/synchronization_cache_controller.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class GlucoseCollector extends ForegroundCollector {
  bool _disposed = false;
  Future<void>? _runner;

  static const _expectedInterval = Duration(minutes: 5, seconds: 10);
  static const _nearReadPollInterval = Duration(seconds: 10);
  static const _fallbackWait = Duration(seconds: 30);

  @override
  void start(CollectorContext context) {
    logI('Starting glucose collector');
    _runner = _run(context);
  }

  Future<void> _run(CollectorContext context) async {
    Glucose? last;

    try {
      last = await _pollGlucose(context);
      if (last != null) {
        _handleGlucose(context, last);
      }
    } catch (e, st) {
      logW('Initial glucose read failed: $e\n$st');
    }

    while (!_disposed) {
      if (last == null) {
        try {
          last = await _pollGlucose(context);
          if (last != null) {
            _handleGlucose(context, last);
          }
        } catch (e, st) {
          logW('Glucose fetch failed: $e\n$st');
        }

        if (last == null) {
          ForegroundAlarmBridge.scheduleCollectTick(
            clock.now().add(_fallbackWait),
          );
          await context.waitForDuration(_fallbackWait);
          continue;
        }
      }

      final knownLast = last;
      final nextExpectedAt = knownLast.date.add(_expectedInterval);
      final waitUntilExpected = nextExpectedAt.difference(clock.now());

      if (waitUntilExpected > Duration.zero) {
        await context.waitForDuration(waitUntilExpected);
      }

      while (!_disposed) {
        try {
          final current = await _pollGlucose(context);
          if (current != null && current.date.isAfter(knownLast.date)) {
            last = current;
            _handleGlucose(context, current);
            break;
          }
        } catch (e, st) {
          logW('Glucose fetch failed: $e\n$st');
        }

        ForegroundAlarmBridge.scheduleCollectTick(
          clock.now().add(_nearReadPollInterval),
        );
        await context.waitForDuration(_nearReadPollInterval);
      }
    }
  }

  Future<Glucose?> _pollGlucose(CollectorContext context) async {
    final repository = await context.container.read(
      glucoseSourceRepositoryProvider.future,
    );
    return repository.pollGlucose();
  }

  void _handleGlucose(CollectorContext context, Glucose data) {
    logI(
      'Glucose reading available ${data.sgv} at ${data.date.toIso8601String()}',
    );

    context.emitEvent(DataAvailableEvent<Glucose>(data));

    ForegroundAlarmBridge.scheduleCollectTick(data.date.add(_expectedInterval));

    if (context.container.read(appLifecycleProvider) ==
        AppLifecycleState.resumed) {
      context.container
          .read(taskEventRouterProvider)
          .send(TaskGlucoseSynchronization(data: data));
    }

    final cache = context.container.read(
      synchronizationCacheControllerProvider,
    );
    cache.cacheGlucose(data);

    context.container.read(bloodSugarValueProvider.notifier).update(data);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _runner;
  }
}

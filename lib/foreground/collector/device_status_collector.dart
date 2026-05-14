import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/device_status.dart';
import '../../core/domain/model/glucose.dart';
import '../../core/logger/logger.dart';
import '../alarm/foreground_alarm_bridge.dart';
import '../event/internal/data_available_event.dart';
import '../providers/device_status_value_provider.dart';
import '../providers/task_event_router_provider.dart';
import '../synchronization/synchronization_cache_controller.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class DeviceStatusCollector extends ForegroundCollector with Logging {
  bool _disposed = false;
  Future<void>? _runner;

  static const _expectedInterval = Duration(minutes: 5);
  static const _nearReadPollInterval = Duration(seconds: 10);
  static const _fallbackWait = Duration(seconds: 30);

  @override
  void start(CollectorContext context) {
    logI("Starting device status collector");
    _runner = _run(context);
  }

  Future<void> _run(CollectorContext context) async {
    DeviceStatus? last;

    try {
      last = await _fetchLastDeviceStatus(context);
      _handleDeviceStatus(context, last);
    } catch (e, st) {
      logW("Initial device status read failed: $e\n$st");
    }

    while (!_disposed) {
      if (last == null) {
        try {
          last = await _fetchLastDeviceStatus(context);
          _handleDeviceStatus(context, last);
        } catch (e, st) {
          logW("Device status fetch failed: $e\n$st");
          await context.waitForDuration(_fallbackWait);
          ForegroundAlarmBridge.scheduleCollectTick(
            clock.now().add(_fallbackWait),
          );
          continue;
        }
      }

      final knownLast = last;

      final nextExpectedAt = knownLast.date.add(_expectedInterval);
      final waitUntilExpected = nextExpectedAt.difference(clock.now());

      if (waitUntilExpected > Duration.zero) {
        await context.waitForDuration(waitUntilExpected);
        ForegroundAlarmBridge.scheduleCollectTick(
          clock.now().add(waitUntilExpected),
        );
      }

      while (!_disposed) {
        try {
          final current = await _fetchLastDeviceStatus(context);

          final isNewStatus =
              current.date.isAfter(knownLast.date) ||
              current.id != knownLast.id;

          if (isNewStatus) {
            last = current;
            _handleDeviceStatus(context, current);

            break;
          }
        } catch (e, st) {
          logW("Device status fetch failed: $e\n$st");
        }

        await context.waitForDuration(_nearReadPollInterval);
        ForegroundAlarmBridge.scheduleCollectTick(
          clock.now().add(_nearReadPollInterval),
        );
      }
    }
  }

  Future<DeviceStatus> _fetchLastDeviceStatus(CollectorContext context) async {
    final repository = await context.container.read(
      deviceStatusSourceRepositoryProvider.future,
    );
    return repository.fetchLastDeviceStatus();
  }

  void _handleDeviceStatus(CollectorContext context, DeviceStatus data) {
    logI("Device status reading available $data");
    logI(
      "Detected change in device status reading ${data.id} at ${data.date.toIso8601String()} "
      "with value ${data.bg} and tick ${data.tick}",
    );

    context.emitEvent(DataAvailableEvent<DeviceStatus>(data));

    final nextAlarm = data.date.add(const Duration(minutes: 5, seconds: 30));
    logI("Scheduling next alarm on ${nextAlarm.toIso8601String()}");
    ForegroundAlarmBridge.scheduleCollectTick(nextAlarm);

    final glucose = Glucose(
      id: data.id,
      externalId: data.externalId,
      source: GlucoseSource.fromStorage(data.source.storageValue),
      sgv: data.bg,
      date: data.date,
      direction: '',
    );

    if (context.container.read(appLifecycleProvider) ==
        AppLifecycleState.resumed) {
      context.container
          .read(taskEventRouterProvider)
          .send(TaskDeviceStatusSynchronization(data: data));
      context.container
          .read(taskEventRouterProvider)
          .send(TaskGlucoseSynchronization(data: glucose));
    }

    final cache = context.container.read(
      synchronizationCacheControllerProvider,
    );
    cache.cacheDeviceStatus(data);
    cache.cacheGlucose(glucose);

    context.container.read(deviceStatusValueProvider.notifier).update(data);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _runner;
  }
}

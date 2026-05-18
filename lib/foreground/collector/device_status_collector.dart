import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../core/data_sources/providers/source_repository_providers.dart';
import '../../core/domain/model/device_status.dart';
import '../../core/logger/logger.dart';
import '../alarm/foreground_alarm_bridge.dart';
import '../event/internal/data_available_event.dart';
import '../providers/device_status_value_provider.dart';
import '../providers/task_event_router_provider.dart';
import '../synchronization/synchronization_cache_controller.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';
import 'helpers/collector_next_reading_helper.dart';

class DeviceStatusCollector extends ForegroundCollector with Logging {
  bool _disposed = false;
  Future<void>? _runner;

  static const _nearReadPollInterval = Duration(seconds: 10);
  static const _fallbackWait = Duration(seconds: 30);
  static const _nextReadingHelper = CollectorNextReadingHelper();

  @override
  void start(CollectorContext context) {
    logI("Starting device status collector");
    _runner = _run(context);
  }

  Future<void> _run(CollectorContext context) async {
    var last = await _loadInitialDeviceStatusFromHistory(context);
    if (last != null) {
      _handleDeviceStatus(context, last);
    }

    if (last == null) {
      try {
        last = await _pollDeviceStatus(context);
        _handleDeviceStatus(context, last);
      } catch (e, st) {
        logW("Initial device status read failed: $e\n$st");
      }
    }

    while (!_disposed) {
      if (last == null) {
        try {
          last = await _pollDeviceStatus(context);
          _handleDeviceStatus(context, last);
        } catch (e, st) {
          logW("Device status fetch failed: $e\n$st");
          ForegroundAlarmBridge.scheduleCollectTick(
            clock.now().add(_fallbackWait),
          );
          await context.waitForDuration(_fallbackWait);
          continue;
        }
      }

      final knownLast = last;

      final nextExpectedAt = _nextExpectedAt(knownLast.date);
      final waitUntilExpected = nextExpectedAt.difference(clock.now());

      if (waitUntilExpected > Duration.zero) {
        await context.waitForDuration(waitUntilExpected);
      }

      while (!_disposed) {
        try {
          final current = await _pollDeviceStatus(context);

          final isNewStatus = current.date.isAfter(knownLast.date);

          if (isNewStatus) {
            last = current;
            _handleDeviceStatus(context, current);

            break;
          }
        } catch (e, st) {
          logW("Device status fetch failed: $e\n$st");
        }

        ForegroundAlarmBridge.scheduleCollectTick(
          clock.now().add(_nearReadPollInterval),
        );
        await context.waitForDuration(_nearReadPollInterval);
      }
    }
  }

  Future<DeviceStatus> _pollDeviceStatus(CollectorContext context) async {
    final repository = await context.container.read(
      deviceStatusSourceRepositoryProvider.future,
    );
    return repository.pollDeviceStatus();
  }

  Future<DeviceStatus?> _loadInitialDeviceStatusFromHistory(
    CollectorContext context,
  ) async {
    try {
      final repository = await context.container.read(
        deviceStatusHistoryRepositoryProvider.future,
      );
      final latest = await repository.fetchLastDeviceStatusBefore(clock.now());
      if (latest == null) return null;

      logI(
        'Initial device status history seed available bg=${latest.bg} '
        'tick=${latest.tick} at ${latest.date.toIso8601String()}',
      );

      return latest;
    } catch (e, st) {
      logW("Initial device status history seed failed: $e\n$st");
      return null;
    }
  }

  void _handleDeviceStatus(CollectorContext context, DeviceStatus data) {
    logI(
      "Device status reading available bg=${data.bg} tick=${data.tick} "
      "at ${data.date.toIso8601String()}",
    );

    context.emitEvent(DataAvailableEvent<DeviceStatus>(data));

    ForegroundAlarmBridge.scheduleCollectTick(_nextExpectedAt(data.date));

    if (context.container.read(appLifecycleProvider) ==
        AppLifecycleState.resumed) {
      context.container
          .read(taskEventRouterProvider)
          .send(TaskDeviceStatusSynchronization(data: data));
    }

    final cache = context.container.read(
      synchronizationCacheControllerProvider,
    );
    cache.cacheDeviceStatus(data);

    context.container.read(deviceStatusValueProvider.notifier).update(data);
  }

  DateTime _nextExpectedAt(DateTime readingDate) {
    return _nextReadingHelper.nextExpectedAt(
      readingDate: readingDate,
      now: clock.now(),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _runner;
  }
}

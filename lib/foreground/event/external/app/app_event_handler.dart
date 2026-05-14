import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/events/data/app/sync_data_key.dart';
import '../../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/logger/logger.dart';
import '../../../alarm/foreground_alarm_bridge.dart';
import '../../../power_monitor/collect_tick_wake_lock.dart';
import '../../../providers/task_event_router_provider.dart';
import '../../../synchronization/synchronization_cache_controller.dart';
import '../../../task/base/runtime_context.dart';
import 'app_event.dart';

class AppEventHandler with Logging {
  AppEventHandler();

  void handle(AppEvent event, RuntimeContext runtimeContext) {
    event.when(
      appLifecycleState: (final data) {
        final state = AppLifecycleState.values[data.state];
        runtimeContext.container
            .read(appLifecycleProvider.notifier)
            .setState(state);
        runtimeContext.emitEvent(data);
        runtimeContext.tick(clock.now());
      },
      dumpLogs: (final data) async {
        final file = await LogFileWriter.writeLogs(Log.bufferedLogs, data.name);
        SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      },
      executeCommand: (final command) {
        logI("Received execute command event");
        command.when(
          syncData: (final data) {
            unawaited(_sendRequestedData(runtimeContext, data));
          },
          syncSettings: (Map<String, String> data) async {
            logI(
              "Received sync settings command, reloading shared prefs, data=$data",
            );
            final sharedPrefs = await runtimeContext.container.read(
              sharedPrefsProvider.future,
            );
            await sharedPrefs.reload();
            runtimeContext.container.invalidate(nightscoutUrlProvider);
            runtimeContext.container.invalidate(dataSourceConfigProvider);
            runtimeContext.container.invalidate(
              glucoseSourceRepositoryProvider,
            );
            runtimeContext.container.invalidate(
              treatmentsSourceRepositoryProvider,
            );
            runtimeContext.container.invalidate(
              deviceStatusSourceRepositoryProvider,
            );

            final cacheController = runtimeContext.container.read(
              synchronizationCacheControllerProvider,
            );
            cacheController.invalidateLiveData();
            await _sendLiveDataFromCurrentSources(runtimeContext);
          },
          collectTick: (String reason, int alarmId) async {
            logI(
              "Received collect tick command with reason: $reason and alarmId: $alarmId",
            );
            await const CollectTickWakeLock().acquire();

            final tickAt = clock.now();
            await ForegroundAlarmBridge.markCollectTickDelivered(tickAt);
            runtimeContext.tick(tickAt);
          },
        );
      },
    );
  }

  Future<void> _sendRequestedData(
    RuntimeContext runtimeContext,
    List<String> data,
  ) async {
    final cacheController = runtimeContext.container.read(
      synchronizationCacheControllerProvider,
    );

    if (data.contains(SyncDataKey.glucoseList)) {
      await cacheController.ensureGlucoseReadingsReady(
        runtimeContext.container,
      );
    }

    final events = <TaskDataSynchronizationPayload>[];
    final cache = cacheController.getCache();
    final router = runtimeContext.container.read(taskEventRouterProvider);

    for (final val in data) {
      switch (val) {
        case SyncDataKey.glucoseList:
          final cachedReadings = cache.glucoseReadingsCache.reversed.toList();
          logI(
            _describeGlucoseReadings(
              'Sending cached glucose list to UI',
              cachedReadings,
            ),
          );
          events.addAll(
            cachedReadings.map((e) => TaskGlucoseSynchronization(data: e)),
          );
          break;
        case SyncDataKey.temporaryTarget:
          final target = cache.targetCache;
          if (target != null) {
            final payload = TaskTargetSynchronization(data: target);
            events.add(payload);
          }
          break;
        case SyncDataKey.deviceStatus:
          final deviceStatus = cache.deviceStatusCache;
          if (deviceStatus != null) {
            final payload = TaskDeviceStatusSynchronization(data: deviceStatus);
            events.add(payload);
          }
          break;
        default:
          logW('Unsupported sync data key: $val');
      }
    }

    if (events.isNotEmpty) {
      router.send(TaskDataSynchronizationPayload.list(data: events));
    }
  }

  Future<void> _sendLiveDataFromCurrentSources(
    RuntimeContext runtimeContext,
  ) async {
    final events = <TaskDataSynchronizationPayload>[];
    final cacheController = runtimeContext.container.read(
      synchronizationCacheControllerProvider,
    );

    await _addGlucoseEvents(runtimeContext, cacheController, events);
    await _addDeviceStatusEvent(runtimeContext, cacheController, events);

    if (events.isEmpty) return;

    runtimeContext.container
        .read(taskEventRouterProvider)
        .send(TaskDataSynchronizationPayload.list(data: events));
  }

  Future<void> _addGlucoseEvents(
    RuntimeContext runtimeContext,
    SynchronizationCacheController cacheController,
    List<TaskDataSynchronizationPayload> events,
  ) async {
    try {
      final repository = await runtimeContext.container.read(
        glucoseHistoryRepositoryProvider.future,
      );
      final now = clock.now();
      final readings = await repository.fetchGlucoseBetween(
        now.subtract(const Duration(hours: 2)),
        now,
      );
      logI(
        _describeGlucoseReadings(
          'Glucose history sync fetch after settings change',
          readings,
        ),
      );
      final orderedReadings = ([
        ...readings,
      ]..sort((a, b) => b.date.compareTo(a.date))).take(10).toList().reversed;

      cacheController.replaceGlucoseReadings(orderedReadings);
      events.addAll(
        orderedReadings.map((data) => TaskGlucoseSynchronization(data: data)),
      );
    } catch (e, st) {
      logW('Live glucose sync after settings change failed: $e\n$st');
    }
  }

  Future<void> _addDeviceStatusEvent(
    RuntimeContext runtimeContext,
    SynchronizationCacheController cacheController,
    List<TaskDataSynchronizationPayload> events,
  ) async {
    try {
      final repository = await runtimeContext.container.read(
        deviceStatusSourceRepositoryProvider.future,
      );
      final data = await repository.pollDeviceStatus();
      cacheController.cacheDeviceStatus(data);
      events.add(TaskDeviceStatusSynchronization(data: data));
    } catch (e, st) {
      logW('Live device status sync after settings change failed: $e\n$st');
    }
  }

  String _describeGlucoseReadings(String label, Iterable<Glucose> readings) {
    final glucoseReadings = readings.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final values = glucoseReadings
        .map((reading) => '${reading.sgv}@${reading.date.toIso8601String()}')
        .join(', ');

    return '$label count=${glucoseReadings.length} values=[$values]';
  }
}

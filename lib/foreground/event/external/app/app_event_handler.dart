import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../core/logger/logger.dart';
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
            final events = <TaskDataSynchronizationPayload>[];

            final cacheController = runtimeContext.container.read(
              synchronizationCacheControllerProvider,
            );
            final cache = cacheController.getCache();
            final router = runtimeContext.container.read(
              taskEventRouterProvider,
            );

            for (final val in data) {
              if (val == 'glucose_list') {
                events.addAll(
                  cache.glucoseReadingsCache.reversed.toList().map(
                    (e) => TaskGlucoseSynchronization(data: e),
                  ),
                );
              }
              if (val == 'temporary_target') {
                final target = cache.targetCache;
                if (target != null) {
                  final payload = TaskTargetSynchronization(data: target);
                  events.add(payload);
                }
              }
              if (val == 'device_status') {
                final deviceStatus = cache.deviceStatusCache;
                if (deviceStatus != null) {
                  final payload = TaskDeviceStatusSynchronization(
                    data: deviceStatus,
                  );
                  events.add(payload);
                }
              }
            }
            if (events.isNotEmpty) {
              router.send(TaskDataSynchronizationPayload.list(data: events));
            }
          },
          syncSettings: (Map<String, String> data) async {
            logI("Received sync settings command, reloading shared prefs");
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
              treatmentSourceRepositoryProvider,
            );
            runtimeContext.container.invalidate(
              deviceStatusSourceRepositoryProvider,
            );
          },
          collectTick: (String reason, int alarmId) async {
            logI(
              "Received collect tick command with reason: $reason and alarmId: $alarmId",
            );

            await FlutterForegroundTask.updateService(
              foregroundTaskOptions: ForegroundTaskOptions(
                allowWakeLock: true,
                allowWifiLock: true,
                eventAction: ForegroundTaskEventAction.nothing(),
              ),
            );

            logI("WakeLock ENABLED for collectTick");

            Future.delayed(const Duration(seconds: 10), () async {
              try {
                await FlutterForegroundTask.updateService(
                  foregroundTaskOptions: ForegroundTaskOptions(
                    allowWakeLock: false,
                    allowWifiLock: false,
                    eventAction: ForegroundTaskEventAction.nothing(),
                  ),
                );
                logI("WakeLock DISABLED after timeout (10)");
              } catch (e, st) {
                logW("Failed to disable WakeLock: $e\n$st");
              }
            });

            runtimeContext.tick(clock.now());
          },
        );
      },
    );
  }
}

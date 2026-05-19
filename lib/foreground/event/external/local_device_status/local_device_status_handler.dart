import 'package:clock/clock.dart';

import '../../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/local_mirror/providers/local_mirror_writer_provider.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/logger/logger.dart';
import '../../../alarm/foreground_alarm_bridge.dart';
import '../../../event/internal/data_available_event.dart';
import '../../../providers/device_status_value_provider.dart';
import '../../../providers/task_event_router_provider.dart';
import '../../../synchronization/synchronization_cache_controller.dart';
import '../../../task/base/runtime_context.dart';
import 'local_device_status_event.dart';

class LocalDeviceStatusHandler with Logging {
  static const _safetyTickInterval = Duration(minutes: 6);

  Future<void> handle(
    LocalDeviceStatusEvent event,
    RuntimeContext runtimeContext,
  ) async {
    final deviceStatus = event.data;
    final container = runtimeContext.container;
    final config = await container.read(dataSourceConfigProvider.future);

    if (!_matchesConfiguredSource(
      config.pumpStatusSource,
      deviceStatus.source,
    )) {
      logI(
        'Ignoring local device status from ${deviceStatus.source.storageValue}; '
        'configured pump status source is ${config.pumpStatusSource.storageValue}',
      );
      return;
    }

    if (config.mirrorToLocal) {
      await container.read(localMirrorWriterProvider).mirrorDeviceStatuses([
        deviceStatus,
      ]);
    }

    container
        .read(synchronizationCacheControllerProvider)
        .cacheDeviceStatus(deviceStatus);
    container.read(deviceStatusValueProvider.notifier).update(deviceStatus);
    runtimeContext.emitEvent(DataAvailableEvent<DeviceStatus>(deviceStatus));
    final tickAt = clock.now();
    runtimeContext.tick(tickAt);
    container
        .read(taskEventRouterProvider)
        .send(TaskDeviceStatusSynchronization(data: deviceStatus));
    await _scheduleSafetyTick(tickAt);
  }

  Future<void> _scheduleSafetyTick(DateTime tickAt) async {
    try {
      await ForegroundAlarmBridge.scheduleCollectTick(
        tickAt.add(_safetyTickInterval),
      );
    } catch (e, st) {
      logW('Failed to schedule local device status safety tick: $e\n$st');
    }
  }

  bool _matchesConfiguredSource(
    PumpStatusSource pumpStatusSource,
    DeviceStatusSource source,
  ) {
    return switch (pumpStatusSource) {
      PumpStatusSource.cloud => source == DeviceStatusSource.cloud,
      PumpStatusSource.aaps => source == DeviceStatusSource.aaps,
    };
  }
}

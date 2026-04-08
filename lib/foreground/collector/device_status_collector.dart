import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_lifecycle_state_provider.dart';
import '../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../core/domain/model/device_status.dart';
import '../event/internal/data_available_event.dart';
import '../providers/device_status_stream_provider.dart';
import '../providers/device_status_value_provider.dart';
import '../providers/task_event_router_provider.dart';
import '../synchronization/synchronization_cache_controller.dart';
import '../task/base/collector_context.dart';
import 'foreground_collector.dart';

class DeviceStatusCollector extends ForegroundCollector {
  late final ProviderSubscription _subscription;

  @override
  void start(CollectorContext context) {
    _subscription = context.container.listen<AsyncValue<DeviceStatus>>(
      deviceStatusStreamProvider,
      (previous, next) {
        next.whenData((data) {
          logI("Device status reading available $data");
          logI(
            "Detected change in device status reading ${data.id} at ${data.date.toIso8601String()} with value ${data.bg} and tick ${data.tick}",
          );
          context.emitEvent(DataAvailableEvent<DeviceStatus>(data));
          if (context.container.read(appLifecycleProvider) ==
              AppLifecycleState.resumed) {
            final payload = TaskDeviceStatusSynchronization(data: data);
            context.container.read(taskEventRouterProvider).send(payload);
          }
          final cache = context.container.read(
            synchronizationCacheControllerProvider,
          );
          cache.cacheDeviceStatus(data);

          context.container
              .read(deviceStatusValueProvider.notifier)
              .update(data);
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

import 'dart:ui';

import 'package:clock/clock.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/local_mirror/providers/local_mirror_writer_provider.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/logger/logger.dart';
import '../../../event/internal/data_available_event.dart';
import '../../../providers/blood_sugar_value_provider.dart';
import '../../../providers/task_event_router_provider.dart';
import '../../../synchronization/synchronization_cache_controller.dart';
import '../../../task/base/runtime_context.dart';
import 'local_glucose_event.dart';

class LocalGlucoseHandler with Logging {
  Future<void> handle(
    LocalGlucoseEvent event,
    RuntimeContext runtimeContext,
  ) async {
    final glucose = event.data;
    final container = runtimeContext.container;
    final config = await container.read(dataSourceConfigProvider.future);

    if (!_matchesConfiguredSource(config.bgSource, glucose.source)) {
      logI(
        'Ignoring local glucose from ${glucose.source.storageValue}; '
        'configured bg source is ${config.bgSource.storageValue}',
      );
      return;
    }

    if (config.mirrorToLocal) {
      await container.read(localMirrorWriterProvider).mirrorGlucose([glucose]);
    }

    container
        .read(synchronizationCacheControllerProvider)
        .cacheGlucose(glucose);
    container.read(bloodSugarValueProvider.notifier).update(glucose);
    runtimeContext.emitEvent(DataAvailableEvent<Glucose>(glucose));
    final tickAt = clock.now();
    runtimeContext.tick(tickAt);
    if (container.read(appLifecycleProvider) == AppLifecycleState.resumed) {
      container
          .read(taskEventRouterProvider)
          .send(TaskDataSynchronizationPayload.glucose(data: glucose));
    }
  }

  bool _matchesConfiguredSource(BgSource bgSource, GlucoseSource source) {
    return switch (bgSource) {
      BgSource.cloud => source == GlucoseSource.cloud,
      BgSource.aaps => source == GlucoseSource.aaps,
      BgSource.xdrip => source == GlucoseSource.xdrip,
    };
  }
}

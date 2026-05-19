import 'package:diabeatthis/common/events/data/task/task_data_synchronization_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_event.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_handler.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_runtime_harness.dart';

void main() {
  group('LocalTreatmentsHandler', () {
    test(
      'emits treatment event and syncs temporary target for AAPS source',
      () async {
        final target = TemporaryTarget(
          nightscoutId: 'target-1',
          createdAt: DateTime(2026, 5, 18, 21, 12),
          durationInMiliseconds: 1800000,
          duration: 30,
          targetBottom: 90,
          targetTop: 110,
        );
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.cloud,
                  treatmentsSource: TreatmentsSource.aaps,
                  pumpStatusSource: PumpStatusSource.cloud,
                  historySource: HistorySource.cloud,
                  mirrorToLocal: false,
                ),
              ),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await LocalTreatmentsHandler().handle(
          LocalTreatmentsEvent(data: [target], rawPayloads: const []),
          harness.runtimeContext,
        );

        expect(harness.emittedEvents, [
          isA<TreatmentAvailableEvent<TemporaryTarget>>(),
        ]);
        expect(
          container
              .read(synchronizationCacheControllerProvider)
              .getCache()
              .targetCache,
          target,
        );
        expect(router.payloads, [TaskTargetSynchronization(data: target)]);

        await harness.dispose();
      },
    );

    test('ignores treatments when configured source is not AAPS', () async {
      final target = TemporaryTarget(
        nightscoutId: 'target-1',
        createdAt: DateTime(2026, 5, 18, 21, 12),
        durationInMiliseconds: 1800000,
        duration: 30,
        targetBottom: 90,
        targetTop: 110,
      );
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(
            const AsyncData(DataSourceConfig.defaults()),
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);

      await LocalTreatmentsHandler().handle(
        LocalTreatmentsEvent(data: [target], rawPayloads: const []),
        harness.runtimeContext,
      );

      expect(harness.emittedEvents, isEmpty);
      expect(
        container
            .read(synchronizationCacheControllerProvider)
            .getCache()
            .targetCache,
        isNull,
      );

      await harness.dispose();
    });
  });
}

class RecordingTaskEventRouter extends TaskEventRouter {
  final List<TaskEventPayload> payloads = [];

  @override
  void send(TaskEventPayload payload) {
    payloads.add(payload);
  }
}

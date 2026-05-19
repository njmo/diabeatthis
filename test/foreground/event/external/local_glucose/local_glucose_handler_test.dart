import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/task/task_data_synchronization_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/event/external/local_glucose/local_glucose_event.dart';
import 'package:diabeatthis/foreground/event/external/local_glucose/local_glucose_handler.dart';
import 'package:diabeatthis/foreground/event/internal/data_available_event.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/blood_sugar_value_provider.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_runtime_harness.dart';

void main() {
  group('LocalGlucoseHandler', () {
    test(
      'updates live state and ticks runtime for matching local source',
      () async {
        final now = DateTime(2026, 5, 18, 12, 30);
        final glucose = Glucose(
          externalId: 'xdrip-${now.millisecondsSinceEpoch}',
          source: GlucoseSource.xdrip,
          date: now,
          sgv: 143,
          direction: 'FortyFiveUp',
        );
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.xdrip,
                  treatmentsSource: TreatmentsSource.cloud,
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

        await withClock(Clock.fixed(now), () async {
          await LocalGlucoseHandler().handle(
            LocalGlucoseEvent(data: glucose),
            harness.runtimeContext,
          );
        });

        expect(container.read(bloodSugarValueProvider), glucose);
        expect(
          container
              .read(synchronizationCacheControllerProvider)
              .getCache()
              .glucoseReadingsCache
              .first,
          glucose,
        );
        expect(harness.emittedEvents, [isA<DataAvailableEvent<Glucose>>()]);
        expect(harness.emittedTicks, [now]);
        expect(router.payloads, [
          TaskDataSynchronizationPayload.glucose(data: glucose),
        ]);

        await harness.dispose();
      },
    );
  });
}

class RecordingTaskEventRouter extends TaskEventRouter {
  final List<TaskEventPayload> payloads = [];

  @override
  void send(TaskEventPayload payload) {
    payloads.add(payload);
  }
}

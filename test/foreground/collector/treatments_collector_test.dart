import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/domain/treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/foreground/collector/treatments_collector.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  group('TreatmentsCollector', () {
    test('does not poll push-based AAPS source', () async {
      final repository = _RecordingTreatmentSourceRepository();
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
          treatmentsSourceRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      final harness = FakeRuntimeHarness(container: container);
      final collector = TreatmentsCollector();

      collector.start(
        CollectorContext.fromRuntimeContext(harness.runtimeContext),
      );
      await _flushMicrotasks();
      await collector.dispose();

      expect(repository.pollCount, 0);
      await harness.dispose();
    });
  });
}

Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _RecordingTreatmentSourceRepository implements TreatmentSourceRepository {
  var pollCount = 0;

  @override
  Future<List<Treatment>> pollTreatments() async {
    pollCount++;
    return const [];
  }
}

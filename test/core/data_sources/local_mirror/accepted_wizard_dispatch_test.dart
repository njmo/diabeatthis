import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/domain/treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/repositories/mirroring_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/repositories/mirroring_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_event.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_handler.dart';
import 'package:diabeatthis/foreground/event/internal/calculator_submission_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  final wizard = BolusWizardDto.fromJson({
    '_id': 'known',
    'created_at': '2026-11-02T14:05:49.906Z',
    'glucose': 135,
    'bolusCalculatorResult': {'carbs': 48, 'totalInsulin': 3},
  }).toDomain(remoteSource: 'https://example.test');
  late DatabaseImpl db;
  late LocalMirrorWriter writer;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    writer = LocalMirrorWriter(db.localMirrorDao);
    await writer.mirrorTreatments([wizard], TreatmentsSource.cloud);
  });
  tearDown(() => db.close());

  test(
    'writer returns accepted canonical records and excludes rejected wizard',
    () async {
      final conflicting = wizard.copyWith(
        createdAt: wizard.createdAt.add(const Duration(seconds: 2)),
      );
      final manual = ManualBolus(
        externalId: 'actual',
        createdAt: conflicting.createdAt.add(const Duration(milliseconds: 800)),
        insulin: 3,
      );
      final accepted = await writer.mirrorTreatments([
        conflicting,
        manual,
      ], TreatmentsSource.cloud);
      expect(accepted, [manual]);
      expect(
        (await db.select(db.bolusWizard).get()).single.createdAt,
        wizard.createdAt.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'cold local cache cannot confirm a wizard rejected by persistence',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dataSourceConfigProvider.overrideWithValue(
            const AsyncData(
              DataSourceConfig(
                bgSource: BgSource.cloud,
                treatmentsSource: TreatmentsSource.aaps,
                pumpStatusSource: PumpStatusSource.cloud,
                historySource: HistorySource.local,
                mirrorToLocal: true,
              ),
            ),
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      final conflicting = wizard.copyWith(nightscoutObjectId: 'rejected');
      await LocalTreatmentsHandler().handle(
        LocalTreatmentsEvent(
          data: [
            conflicting,
            ManualBolus(
              externalId: 'actual',
              createdAt: wizard.createdAt.add(
                const Duration(milliseconds: 800),
              ),
              insulin: 3,
            ),
          ],
          rawPayloads: const [],
        ),
        harness.runtimeContext,
      );
      expect(container.read(calculatorSubmissionsProvider), isEmpty);
      expect(
        harness.emittedEvents.whereType<CalculatorSubmissionChangedEvent>(),
        isEmpty,
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<BolusWizard>>(),
        isEmpty,
      );
      expect(
        harness.emittedEvents.whereType<TreatmentAvailableEvent<ManualBolus>>(),
        hasLength(1),
      );
      await harness.dispose();
    },
  );

  test('cloud poll and history expose only accepted wizard records', () async {
    final source = StaticWizardTreatments([
      wizard.copyWith(nightscoutObjectId: 'rejected'),
    ]);
    final poll = MirroringTreatmentSourceRepository(
      delegate: source,
      mirrorWriter: writer,
      source: TreatmentsSource.cloud,
    );
    final history = MirroringTreatmentsHistoryRepository(
      delegate: source,
      mirrorWriter: writer,
      source: TreatmentsSource.cloud,
    );
    expect(await poll.pollTreatments(), isEmpty);
    expect(
      await history.fetchTreatmentsBetween(wizard.createdAt, wizard.createdAt),
      isEmpty,
    );
  });
}

class StaticWizardTreatments
    implements TreatmentSourceRepository, TreatmentsHistoryRepository {
  const StaticWizardTreatments(this.records);
  final List<Treatment> records;
  @override
  Future<List<Treatment>> pollTreatments() async => records;
  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async => records;
  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}

import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime.utc(2026, 11, 2, 16, 25, 12, 746);
  final wizard = BolusWizardDto.fromJson({
    'created_at': time.toIso8601String(),
    'glucose': 125,
    'bolusCalculatorResult': {'carbs': 12, 'totalInsulin': 0},
  }).toDomain();
  final carbs = Treat(
    externalId: 'carbs',
    createdAt: time.add(const Duration(milliseconds: 849)),
    carbs: 12,
  );
  final actual = ManualBolus(
    externalId: 'actual',
    createdAt: carbs.createdAt,
    insulin: 3,
  );

  test(
    'explicit zero plus a confirmed component completes without delivery',
    () {
      final submission = CalculatorSubmission(
        wizard: wizard.copyWith(carbohydrateRecord: carbs),
      );
      expect(submission.isComplete, isTrue);
      expect(
        submission.status,
        CalculatorSubmissionStatus.completedWithoutInsulin,
      );
      expect(submission.delivery, isNull);
      expect(submission.deliveredInsulin, isNull);
    },
  );

  test(
    'missing, invalid, mismatched or late evidence never completes zero',
    () {
      final cases = [
        wizard,
        wizard.copyWith(carbohydrateRecord: carbs.copyWith(isValid: false)),
        wizard.copyWith(carbohydrateRecord: carbs.copyWith(carbs: 13)),
        wizard.copyWith(
          carbohydrateRecord: carbs.copyWith(
            createdAt: time.add(const Duration(milliseconds: 10001)),
          ),
        ),
        wizard.copyWith(isValid: false, carbohydrateRecord: carbs),
        for (final insulin in [null, 1.0, -1.0, double.nan, double.infinity])
          wizard.copyWith(
            calculatorResult: wizard.calculatorResult!.copyWith(
              totalInsulin: insulin,
            ),
            carbohydrateRecord: carbs,
          ),
      ];
      for (final candidate in cases) {
        expect(CalculatorSubmission(wizard: candidate).isComplete, isFalse);
      }
    },
  );

  test(
    'actual insulin takes precedence while invalid actual stays unresolved',
    () {
      final complete = wizard.copyWith(carbohydrateRecord: carbs);
      final withActual = CalculatorSubmission(
        wizard: complete,
        delivery: actual,
      );
      expect(withActual.status, CalculatorSubmissionStatus.deliveryConfirmed);
      expect(withActual.deliveredInsulin, 3);
      expect(
        CalculatorSubmission(
          wizard: complete,
          delivery: actual.copyWith(isValid: false),
        ).isComplete,
        isFalse,
      );
      expect(
        CalculatorSubmission(
          wizard: complete,
          hasUnresolvedDelivery: true,
        ).isComplete,
        isFalse,
      );
    },
  );

  test(
    'cache accepts separate raw frames in either order and retains tombstones',
    () {
      for (final records in <List<Treatment>>[
        [wizard, carbs],
        [carbs, wizard],
      ]) {
        final container = ProviderContainer();
        final cache = container.read(calculatorSubmissionsProvider.notifier);
        for (final record in records) {
          cache.record(record);
        }
        expect(
          container.read(calculatorSubmissionsProvider).single.isComplete,
          isTrue,
        );
        expect(
          cache.records.whereType<BolusWizard>().single.carbohydrateRecord,
          carbs,
        );
        expect(cache.record(carbs), isEmpty);
        final invalid = carbs.copyWith(isValid: false);
        expect(cache.record(invalid).single.isComplete, isFalse);
        expect(cache.records, contains(invalid));
        expect(
          cache.records.whereType<BolusWizard>().single.carbohydrateRecord,
          isNull,
        );
        container.dispose();
      }
    },
  );

  test(
    'cache cannot turn invalidated positive delivery into zero completion',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cache = container.read(calculatorSubmissionsProvider.notifier);
      cache.record(wizard);
      cache.record(carbs);
      cache.record(actual);
      expect(
        container.read(calculatorSubmissionsProvider).single.status,
        CalculatorSubmissionStatus.deliveryConfirmed,
      );
      cache.record(actual.copyWith(isValid: false));
      expect(
        container.read(calculatorSubmissionsProvider).single.isComplete,
        isFalse,
      );
    },
  );

  test('UTC and local component replay share one grouping identity', () {
    final localCarbs = carbs.copyWith(createdAt: carbs.createdAt.toLocal());
    final enriched = wizard.copyWith(carbohydrateRecord: localCarbs);
    final grouping = BolusWizardGrouping([enriched, carbs]);
    expect(grouping.carbohydrateWizards.keys, [carbs]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cache = container.read(calculatorSubmissionsProvider.notifier);
    cache.record(enriched);
    cache.record(carbs);
    expect(
      container.read(calculatorSubmissionsProvider).single.isComplete,
      isTrue,
    );
    cache.record(localCarbs.copyWith(isValid: false));
    expect(
      container.read(calculatorSubmissionsProvider).single.isComplete,
      isFalse,
    );
    expect(cache.records.whereType<Treat>(), hasLength(1));
  });

  test(
    'writer returns the post-reconciliation wizard in a combined batch',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final accepted = await LocalMirrorWriter(
        db.localMirrorDao,
      ).mirrorTreatments([wizard, carbs], TreatmentsSource.aaps);
      final canonical = accepted.whereType<BolusWizard>().single;
      expect(canonical.localId, isNull);
      expect(canonical.carbohydrateRecord?.carbs, 12);
      expect(CalculatorSubmission(wizard: canonical).isComplete, isTrue);
      expect(await db.select(db.manualBolus).get(), isEmpty);
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );

  test(
    'carbohydrate-only frames publish component addition and invalidation',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      await writer.mirrorTreatments([wizard], TreatmentsSource.aaps);
      final accepted = await writer.mirrorTreatments([
        carbs,
      ], TreatmentsSource.aaps);
      final canonical = accepted.whereType<BolusWizard>().single;
      expect(CalculatorSubmission(wizard: canonical).isComplete, isTrue);
      final replay = await writer.mirrorTreatments([
        carbs,
      ], TreatmentsSource.aaps);
      expect(replay.whereType<BolusWizard>(), isEmpty);
      final revoked = await writer.mirrorTreatments([
        carbs.copyWith(isValid: false, createdAt: carbs.createdAt.toLocal()),
      ], TreatmentsSource.aaps);
      final pending = revoked.whereType<BolusWizard>().single;
      expect(pending.carbohydrateRecord, isNull);
      expect(CalculatorSubmission(wizard: pending).isComplete, isFalse);
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );

  test(
    'duplicate wizard frames never publish a stale component after reconciliation',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final accepted = await LocalMirrorWriter(
        db.localMirrorDao,
      ).mirrorTreatments([wizard, wizard, carbs], TreatmentsSource.aaps);
      expect(accepted.whereType<BolusWizard>(), hasLength(2));
      expect(
        accepted.whereType<BolusWizard>().every(
          (record) => CalculatorSubmission(wizard: record).isComplete,
        ),
        isTrue,
      );
    },
  );

  test(
    'a rejected calculator identity cannot confirm another calculator with its carbs',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      final known = wizard.copyWith(
        nightscoutObjectId: 'known',
        remoteSource: 'https://example.test',
      );
      await writer.mirrorTreatments([known], TreatmentsSource.cloud);
      final accepted = await writer.mirrorTreatments([
        known.copyWith(nightscoutObjectId: 'conflict'),
        carbs,
      ], TreatmentsSource.cloud);
      expect(accepted.whereType<BolusWizard>(), isEmpty);
      expect(accepted.whereType<Treat>(), isEmpty);
      expect(
        (await db.select(db.bolusWizard).get()).single.carbohydrateComponent,
        isNull,
      );
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );

  test(
    'rejecting conflicting components preserves prior ownership and unrelated intake',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      final known = wizard.copyWith(
        nightscoutObjectId: 'known',
        remoteSource: 'https://example.test',
      );
      await writer.mirrorTreatments([known, carbs], TreatmentsSource.cloud);
      final originalComponent =
          (await db.select(db.bolusWizard).get()).single.carbohydrateComponent;
      final independent = carbs.copyWith(
        externalId: 'independent',
        createdAt: time.add(const Duration(seconds: 20)),
        carbs: 7,
      );
      final accepted = await writer.mirrorTreatments([
        known.copyWith(nightscoutObjectId: 'conflict'),
        carbs.copyWith(externalId: 'rejected-component'),
        independent,
      ], TreatmentsSource.cloud);
      expect(accepted, [independent]);
      expect(
        (await db.select(db.bolusWizard).get()).single.carbohydrateComponent,
        originalComponent,
      );
      final storedCarbs = await db.select(db.treat).get();
      expect(storedCarbs, hasLength(1));
      expect(storedCarbs.single.externalId, independent.externalId);
      expect(storedCarbs.single.carbs, 7);
    },
  );

  test(
    'zero-amount invalidation retains prior positive delivery evidence',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      await writer.mirrorTreatments([
        wizard,
        carbs,
        actual,
      ], TreatmentsSource.aaps);
      final invalidation = await writer.mirrorTreatments([
        actual.copyWith(isValid: false, insulin: 0),
      ], TreatmentsSource.aaps);
      expect(
        invalidation.whereType<BolusWizard>().single.hasUnresolvedDelivery,
        isTrue,
      );
      final saved = (await db.select(db.bolusWizard).get()).single.toDomain();
      expect(saved.hasUnresolvedDelivery, isTrue);
      expect(saved.carbohydrateRecord, isNotNull);
      expect(CalculatorSubmission(wizard: saved).isComplete, isFalse);
      expect(await db.select(db.manualBolus).get(), isEmpty);
      await writer.mirrorTreatments([wizard, carbs], TreatmentsSource.aaps);
      expect(
        (await db.select(db.bolusWizard).get()).single
            .toDomain()
            .hasUnresolvedDelivery,
        isTrue,
      );
    },
  );

  test(
    'marker-only evidence survives component removal without restoring fake carbs',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      await writer.mirrorTreatments([
        wizard,
        carbs,
        actual,
      ], TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        actual.copyWith(isValid: false),
        carbs.copyWith(isValid: false),
      ], TreatmentsSource.aaps);
      final saved = (await db.select(db.bolusWizard).get()).single.toDomain();
      expect(saved.hasUnresolvedDelivery, isTrue);
      expect(saved.carbohydrateRecord, isNull);
      await writer.mirrorTreatments([
        wizard.copyWith(isValid: false),
      ], TreatmentsSource.aaps);
      expect(await db.select(db.bolusWizard).get(), isEmpty);
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );
}

import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;

void main() {
  late DatabaseImpl db;
  late LocalMirrorWriter writer;
  final at = DateTime(2026, 11, 26, 12);

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    writer = LocalMirrorWriter(db.localMirrorDao);
  });
  tearDown(() => db.close());

  Future<bool> cancelled(DateTime wizardAt) async =>
      (await db.select(db.bolusWizard).get())
          .singleWhere(
            (row) => row.createdAt == wizardAt.millisecondsSinceEpoch,
          )
          .toDomain()
          .hasUnresolvedDelivery;

  test('a cancelled bolus marks only the calculator it belonged to', () async {
    final first = testBolusWizard(createdAt: at, carbs: 20, insulin: 4);
    final second = testBolusWizard(
      createdAt: at.add(const Duration(seconds: 40)),
      carbs: 5,
      insulin: 1,
    );
    final delivery = ManualBolus(
      externalId: 'second-delivery',
      createdAt: second.createdAt.add(const Duration(seconds: 1)),
      insulin: 1,
    );
    await writer.mirrorTreatments([
      first,
      second,
      delivery,
    ], TreatmentsSource.aaps);
    await writer.mirrorTreatments([
      delivery.copyWith(isValid: false),
    ], TreatmentsSource.aaps);

    expect(await cancelled(second.createdAt), isTrue);
    expect(await cancelled(first.createdAt), isFalse);
  });

  test(
    'cancelling an unrelated bolus keeps a delivered calculator unmarked',
    () async {
      final wizard = testBolusWizard(createdAt: at, carbs: 20, insulin: 4);
      final own = ManualBolus(
        externalId: 'own',
        createdAt: at.add(const Duration(seconds: 1)),
        insulin: 4,
      );
      final unrelated = ManualBolus(
        externalId: 'unrelated',
        createdAt: at.add(const Duration(seconds: 90)),
        insulin: 1,
      );
      await writer.mirrorTreatments([
        wizard,
        own,
        unrelated,
      ], TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        unrelated.copyWith(isValid: false),
      ], TreatmentsSource.aaps);

      expect(await cancelled(wizard.createdAt), isFalse);
    },
  );

  test(
    "a later calculator's own bolus does not hide an earlier cancellation",
    () async {
      final first = testBolusWizard(createdAt: at, carbs: 20, insulin: 4);
      final cancelledBolus = ManualBolus(
        externalId: 'first-delivery',
        createdAt: at.add(const Duration(seconds: 5)),
        insulin: 4,
      );
      final second = testBolusWizard(
        createdAt: at.add(const Duration(seconds: 20)),
        carbs: 5,
        insulin: 1,
      );
      final secondBolus = ManualBolus(
        externalId: 'second-delivery',
        createdAt: at.add(const Duration(seconds: 30)),
        insulin: 1,
      );
      await writer.mirrorTreatments([
        first,
        cancelledBolus,
        second,
        secondBolus,
      ], TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        cancelledBolus.copyWith(isValid: false),
      ], TreatmentsSource.aaps);

      expect(await cancelled(first.createdAt), isTrue);
      expect(await cancelled(second.createdAt), isFalse);
    },
  );
}

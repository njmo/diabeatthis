import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/models/wizard_carbohydrate_component.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/models/wizard_submission_evidence.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/manual_bolus.dart' as domain;
import 'package:diabeatthis/core/domain/model/treat.dart' as domain;
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late LocalMirrorWriter writer;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    writer = LocalMirrorWriter(db.localMirrorDao);
  });

  tearDown(() => db.close());

  for (final source in TreatmentsSource.values) {
    test(
      'does not persist calculator carbs from a complete ${source.name} batch',
      () async {
        final first = calculatorSubmission();
        final second = calculatorSubmission(
          time: DateTime(2026, 11, 2, 15, 6),
          carbs: 13,
          recommendation: 24.2,
          insulinDelay: 798,
          carbDelay: 798,
        );
        await writer.mirrorTreatments([...first, ...second].reversed, source);

        expect(await db.select(db.treat).get(), isEmpty);
        expect(await db.select(db.bolusWizard).get(), hasLength(2));
        final deliveries = await db.select(db.manualBolus).get();
        expect(deliveries, hasLength(2));
        expect(deliveries.map((row) => row.insulin), everyElement(3));
      },
    );
  }

  for (final order in recordOrders([0, 1, 2])) {
    test('reconciles separately delivered records in order $order', () async {
      final records = calculatorSubmission();
      for (final index in order) {
        await writer.mirrorTreatments([records[index]], TreatmentsSource.aaps);
      }
      expect(await db.select(db.treat).get(), isEmpty);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
      expect((await db.select(db.manualBolus).getSingle()).insulin, 3);

      // A repeated local broadcast or later remote history must not recreate it.
      await writer.mirrorTreatments([records.last], TreatmentsSource.aaps);
      await writer.mirrorTreatments(records, TreatmentsSource.cloud);
      expect(await db.select(db.treat).get(), isEmpty);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
    });
  }

  test(
    'keeps a partial trailing submission until its delivery arrives',
    () async {
      final records = calculatorSubmission();
      await writer.mirrorTreatments([records.last], TreatmentsSource.aaps);
      expect(await db.select(db.treat).get(), hasLength(1));
      await writer.mirrorTreatments([records.first], TreatmentsSource.aaps);
      expect(await db.select(db.treat).get(), hasLength(1));

      await writer.mirrorTreatments([records[1]], TreatmentsSource.aaps);
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );

  test('also removes carbs delivered before the calculator', () async {
    final records = calculatorSubmission(carbDelay: -1000);
    await writer.mirrorTreatments([records.last], TreatmentsSource.aaps);
    expect(await db.select(db.treat).get(), hasLength(1));
    await writer.mirrorTreatments([records.first], TreatmentsSource.aaps);
    expect(await db.select(db.treat).get(), isEmpty);
    await writer.mirrorTreatments([records[1]], TreatmentsSource.aaps);
    expect(await db.select(db.treat).get(), isEmpty);
    expect((await db.select(db.manualBolus).getSingle()).insulin, 3);
  });

  test(
    'preserves independent intake near and outside calculator submissions',
    () async {
      final records = calculatorSubmission();
      final wizard = records.first as domain.BolusWizard;
      final nearby = domain.Treat(
        externalId: 'independent-nearby',
        createdAt: wizard.createdAt.add(const Duration(seconds: 4)),
        carbs: 7,
      );
      final distant = nearby.copyWith(
        externalId: 'independent-distant',
        createdAt: wizard.createdAt.subtract(const Duration(minutes: 30)),
        carbs: 48,
      );
      await writer.mirrorTreatments([
        ...records,
        nearby,
        distant,
      ], TreatmentsSource.aaps);
      expect(
        (await db.select(db.treat).get()).map((row) => row.carbs),
        unorderedEquals([7, 48]),
      );
    },
  );

  test(
    'invalid calculator cannot remove an otherwise independent carb record',
    () async {
      final records = calculatorSubmission();
      final wizard = records.first as domain.BolusWizard;
      await writer.mirrorTreatments([
        wizard.copyWith(isValid: false),
        ...records.skip(1),
      ], TreatmentsSource.aaps);
      expect(await db.select(db.treat).get(), hasLength(1));
      expect(await db.select(db.bolusWizard).get(), isEmpty);
    },
  );

  test(
    'rejected conflicting calculator cannot claim the incoming carbs',
    () async {
      final records = calculatorSubmission();
      final incoming = records.first as domain.BolusWizard;
      final stored = incoming.copyWith(
        nightscoutObjectId: 'existing-calculator',
        calculatorResult: incoming.calculatorResult!.copyWith(carbs: 20),
      );
      await writer.mirrorTreatments([stored], TreatmentsSource.cloud);
      await writer.mirrorTreatments(records, TreatmentsSource.cloud);

      expect((await db.select(db.bolusWizard).getSingle()).carbs, 20);
      expect((await db.select(db.treat).getSingle()).carbs, 48);
    },
  );

  test(
    'retains the original carbohydrate record inside its calculator',
    () async {
      final records = calculatorSubmission();
      final original = records.last as domain.Treat;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      final wizard = await db.select(db.bolusWizard).getSingle();
      final component = WizardCarbohydrateComponent.fromJson(
        wizard.carbohydrateComponent!,
      );
      expect(component.source, 'aaps');
      expect(component.externalId, original.externalId);
      expect(component.createdAt, original.createdAt);
      expect(component.carbs, original.carbs);
      expect(component.treatment, original);
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );

  test(
    'validated calculator invalidation restores its original carbohydrates',
    () async {
      final records = calculatorSubmission();
      final wizard = records.first as domain.BolusWizard;
      final original = records.last as domain.Treat;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        wizard.copyWith(isValid: false),
      ], TreatmentsSource.aaps);
      expect(await db.select(db.bolusWizard).get(), isEmpty);
      final restored = await db.select(db.treat).getSingle();
      expect(restored.carbs, 48);
      expect(restored.externalId, original.externalId);
      expect(restored.source, 'aaps');
      expect(restored.createdAt, original.createdAt.millisecondsSinceEpoch);
    },
  );

  test(
    'conflicting calculator invalidation keeps the component attached',
    () async {
      final records = calculatorSubmission();
      final wizard = records.first as domain.BolusWizard;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        wizard.copyWith(
          isValid: false,
          nightscoutObjectId: 'unrelated-calculator',
        ),
      ], TreatmentsSource.aaps);
      expect(
        (await db.select(db.bolusWizard).getSingle()).carbohydrateComponent,
        isNotNull,
      );
      expect(await db.select(db.treat).get(), isEmpty);
    },
  );

  test(
    'a carbohydrate correction replaces the attached original and can reattach',
    () async {
      final records = calculatorSubmission();
      final original = records.last as domain.Treat;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        original.copyWith(carbs: 7),
      ], TreatmentsSource.aaps);
      expect((await db.select(db.treat).getSingle()).carbs, 7);
      expect(
        (await db.select(db.bolusWizard).getSingle()).carbohydrateComponent,
        isNull,
      );
      await writer.mirrorTreatments([original], TreatmentsSource.aaps);
      expect(await db.select(db.treat).get(), isEmpty);
      expect(
        (await db.select(db.bolusWizard).getSingle()).carbohydrateComponent,
        isNotNull,
      );
    },
  );

  test(
    'correcting calculator carbohydrates restores an unmatched component',
    () async {
      final records = calculatorSubmission();
      final wizard = records.first as domain.BolusWizard;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        wizard.copyWith(
          calculatorResult: wizard.calculatorResult!.copyWith(carbs: 20),
        ),
      ], TreatmentsSource.aaps);
      expect((await db.select(db.treat).getSingle()).carbs, 48);
      expect(
        (await db.select(db.bolusWizard).getSingle()).carbohydrateComponent,
        isNull,
      );
    },
  );

  test(
    'invalidating the delivery restores an unproven trailing component',
    () async {
      final records = calculatorSubmission();
      final insulin = records[1] as domain.ManualBolus;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      await writer.mirrorTreatments([
        insulin.copyWith(isValid: false),
      ], TreatmentsSource.aaps);
      expect(await db.select(db.manualBolus).get(), isEmpty);
      expect((await db.select(db.treat).getSingle()).carbs, 48);
      final evidence = WizardSubmissionEvidence.fromJson(
        (await db.select(db.bolusWizard).getSingle()).carbohydrateComponent,
      );
      expect(evidence.carbohydrates, isNull);
      expect(evidence.hasUnresolvedDelivery, isTrue);
    },
  );

  test(
    'an already attached leading component prevents claiming another intake',
    () async {
      final records = calculatorSubmission(carbDelay: -1000);
      final wizard = records.first as domain.BolusWizard;
      final original = records.last as domain.Treat;
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      final independent = original.copyWith(
        externalId: 'independent-later',
        createdAt: wizard.createdAt.add(const Duration(seconds: 2)),
      );
      await writer.mirrorTreatments([independent], TreatmentsSource.aaps);
      expect(
        (await db.select(db.treat).getSingle()).externalId,
        independent.externalId,
      );
      final component = WizardCarbohydrateComponent.fromJson(
        (await db.select(db.bolusWizard).getSingle()).carbohydrateComponent!,
      );
      expect(component.createdAt, original.createdAt);
    },
  );
}

List<Treatment> calculatorSubmission({
  DateTime? time,
  int carbs = 48,
  double recommendation = 44.7,
  int insulinDelay = 830,
  int carbDelay = 831,
}) {
  final at = time ?? DateTime(2026, 11, 2, 15, 5);
  final identity = at.millisecondsSinceEpoch.toString();
  return TreatmentFactory().parseTreatments([
    {
      '_id': 'wizard-$identity',
      'eventType': 'Bolus Wizard',
      'created_at': at.toIso8601String(),
      'glucose': 135,
      'bolusCalculatorResult': {'carbs': carbs, 'totalInsulin': recommendation},
    },
    {
      '_id': 'insulin-$identity',
      'eventType': 'Meal Bolus',
      'created_at': at
          .add(Duration(milliseconds: insulinDelay))
          .toIso8601String(),
      'insulin': 3.0,
    },
    {
      '_id': 'carbs-$identity',
      'eventType': 'Meal Bolus',
      'created_at': at.add(Duration(milliseconds: carbDelay)).toIso8601String(),
      'carbs': carbs,
    },
  ]);
}

Iterable<List<int>> recordOrders(List<int> records) sync* {
  if (records.isEmpty) {
    yield [];
    return;
  }
  for (var index = 0; index < records.length; index++) {
    final remaining = [...records]..removeAt(index);
    for (final rest in recordOrders(remaining)) {
      yield [records[index], ...rest];
    }
  }
}

import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/day_analysis/build_day_context_use_case_test.dart'
    show emptyMeals;

void main() {
  test(
    'attaches the observed 892ms trailing carb pair without inventing insulin',
    () {
      final pair = zeroInsulinPair();
      for (final records in [
        [pair.wizard, pair.carbs],
        [pair.carbs, pair.wizard],
      ]) {
        final grouping = BolusWizardGrouping(records);
        expect(grouping.relatedRecords, {pair.carbs});
        expect(grouping.carbohydrateWizards, {pair.carbs: pair.wizard});
        expect(records.whereType<ManualBolus>(), isEmpty);
        expect(
          CalculatorSubmission(wizard: pair.wizard).status,
          CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
        );
      }
    },
  );

  test('requires explicit zero rather than unknown or nonzero insulin', () {
    for (final recommendation in [
      null,
      1.0,
      -1.0,
      double.nan,
      double.infinity,
    ]) {
      final pair = zeroInsulinPair(recommendation: recommendation);
      expect(
        BolusWizardGrouping([pair.wizard, pair.carbs]).relatedRecords,
        isEmpty,
      );
    }
    final pair = zeroInsulinPair();
    expect(
      BolusWizardGrouping([
        pair.wizard.copyWith(calculatorResult: null),
        pair.carbs,
      ]).relatedRecords,
      isEmpty,
    );
  });

  test(
    'keeps the existing ten-second boundary for zero-insulin submissions',
    () {
      for (final delay in [10000, 10001]) {
        final pair = zeroInsulinPair(delay: delay);
        expect(
          BolusWizardGrouping([pair.wizard, pair.carbs]).isRelated(pair.carbs),
          delay <= 10000,
        );
      }
    },
  );

  test('keeps differing amounts and invalid components independent', () {
    final pair = zeroInsulinPair();
    for (final records in <List<Treatment>>[
      [pair.wizard, pair.carbs.copyWith(carbs: 13)],
      [pair.wizard, pair.carbs.copyWith(isValid: false)],
      [pair.wizard.copyWith(isValid: false), pair.carbs],
    ]) {
      expect(BolusWizardGrouping(records).relatedRecords, isEmpty);
    }
  });

  test(
    'does not search past another treatment or choose ambiguous records',
    () {
      final pair = zeroInsulinPair();
      final intervening = CorrectionBolus(
        externalId: 'intervening',
        createdAt: pair.wizard.createdAt.add(const Duration(milliseconds: 100)),
        insulin: 0.1,
      );
      for (final records in <List<Treatment>>[
        [pair.wizard, intervening, pair.carbs],
        [
          pair.wizard,
          pair.carbs,
          pair.carbs.copyWith(externalId: 'other-carbs'),
        ],
        [
          pair.wizard,
          pair.wizard.copyWith(nightscoutObjectId: 'other-calculator'),
          pair.carbs,
        ],
      ]) {
        expect(BolusWizardGrouping(records).relatedRecords, isEmpty);
      }
    },
  );

  test('does not claim a second intake when leading carbs already match', () {
    final pair = zeroInsulinPair();
    final leading = pair.carbs.copyWith(
      externalId: 'leading',
      createdAt: pair.wizard.createdAt.subtract(const Duration(seconds: 1)),
    );
    expect(
      BolusWizardGrouping([leading, pair.wizard, pair.carbs]).relatedRecords,
      {leading},
    );
  });

  for (final source in TreatmentsSource.values) {
    for (final carbsFirst in [true, false]) {
      test(
        'persists ${source.name} zero-insulin components across separate batches carbsFirst=$carbsFirst',
        () async {
          final db = DatabaseImpl(NativeDatabase.memory());
          addTearDown(db.close);
          final writer = LocalMirrorWriter(db.localMirrorDao);
          final pair = zeroInsulinPair();
          final records = carbsFirst
              ? [pair.carbs, pair.wizard]
              : [pair.wizard, pair.carbs];
          for (final record in records) {
            await writer.mirrorTreatments([record], source);
          }
          await writer.mirrorTreatments(records.reversed, source);
          expect(await db.select(db.treat).get(), isEmpty);
          expect(await db.select(db.manualBolus).get(), isEmpty);
          final stored = (await db.select(db.bolusWizard).get()).single;
          expect(stored.insulin, 0);
          expect(stored.carbohydrateComponent, isNotNull);
          final history =
              await LocalTreatmentsHistoryRepository(
                db.localMirrorDao,
              ).fetchTreatmentsBetween(
                pair.wizard.createdAt.subtract(const Duration(minutes: 1)),
                pair.carbs.createdAt.add(const Duration(minutes: 1)),
              );
          expect(history.whereType<Treat>(), isEmpty);
          final wizard = history.whereType<BolusWizard>().single;
          expect(wizard.carbohydrateRecord?.carbs, 48);
          expect(
            CalculatorSubmission(wizard: wizard).status,
            CalculatorSubmissionStatus.completedWithoutInsulin,
          );
          expect(CalculatorSubmission(wizard: wizard).deliveredInsulin, isNull);
        },
      );
    }
  }

  test(
    'day review excludes calculator carbs and still reports no delivered insulin',
    () async {
      final pair = zeroInsulinPair();
      final independent = pair.carbs.copyWith(
        externalId: 'independent',
        carbs: 7,
        createdAt: pair.carbs.createdAt.add(const Duration(minutes: 1)),
      );
      final result = await BuildDayContextUseCase(
        now: () => pair.wizard.createdAt.add(const Duration(hours: 1)),
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [pair.carbs, independent, pair.wizard],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      )(date: pair.wizard.createdAt);
      expect(result.carbEntries, [independent]);
      expect(result.wizards, [pair.wizard]);
      expect(result.boluses!.units, 0);
      expect(result.boluses!.count, 0);
    },
  );
}

({BolusWizard wizard, Treat carbs}) zeroInsulinPair({
  double? recommendation = 0,
  int delay = 892,
}) {
  final time = DateTime.utc(2026, 1, 1, 12);
  final records = TreatmentFactory().parseTreatments([
    {
      '_id': 'zero-calculator',
      'eventType': 'Bolus Wizard',
      'created_at': time.toIso8601String(),
      'glucose': 125,
      'bolusCalculatorResult': {
        'carbs': 48,
        if (recommendation != null) 'totalInsulin': recommendation,
      },
    },
    {
      '_id': 'submitted-carbs',
      'eventType': 'Meal Bolus',
      'created_at': time.add(Duration(milliseconds: delay)).toIso8601String(),
      'carbs': 48,
    },
  ]);
  return (
    wizard: records.whereType<BolusWizard>().single,
    carbs: records.whereType<Treat>().single,
  );
}

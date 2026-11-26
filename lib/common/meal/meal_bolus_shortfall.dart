import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_sources/config/data_source_config.dart';
import '../../core/data_sources/config/data_source_config_provider.dart';
import '../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treatment_base.dart';
import '../../core/drift/database_impl.dart' show BolusWizardData, DatabaseImpl;
import '../../core/drift/providers/database_provider.dart';
import '../../foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'meal_bolus_delivery.dart';
import 'meal_calculator_submission.dart';

typedef MealBolusShortfall = ({double delivered, double recommended});

typedef MealBolusRecord = ({
  TreatmentsSource source,
  double? recorded,
  double recommended,
  // The insulin record of this calculator was cancelled in AAPS.
  bool cancelled,
});

/// The meal advances on the calculator entry alone; these records only inform
/// the meal card. With the local mirror the insulin records are in the
/// database. Without it they are read from the treatments history
/// (Nightscout), which is polled until every calculator has an outcome.
final mealBolusRecordsProvider = StreamProvider.autoDispose
    .family<List<MealBolusRecord>, int>((ref, mealId) async* {
      final db = ref.watch(databaseProvider);
      final config = ref.watch(dataSourceConfigProvider).value;
      final fromHistory = config != null && !config.mirrorToLocal;
      final history = fromHistory
          ? ref.watch(mealBolusDeliveryHistoryProvider)
          : null;
      final changes = StreamController<void>();
      final subscription = db
          .customSelect(
            'SELECT 1 FROM meal_wizard_link '
            'WHERE meal_id = ? AND dismissed = 0',
            variables: [Variable(mealId)],
            readsFrom: {db.mealWizardLink, db.bolusWizard, db.manualBolus},
          )
          .watch()
          .listen((_) => changes.add(null), onError: changes.addError);
      Timer? poll;
      ref.onDispose(() {
        poll?.cancel();
        subscription.cancel();
        changes.close();
      });
      await for (final _ in changes.stream) {
        final records = await readMealBolusRecords(
          db,
          mealId,
          history: history,
        );
        yield records;
        final pending = records.any(
          (record) => record.recorded == null && !record.cancelled,
        );
        if (history != null && pending) {
          poll ??= Timer.periodic(
            mealBolusRecordsPollInterval,
            (_) => changes.isClosed ? null : changes.add(null),
          );
        } else {
          poll?.cancel();
          poll = null;
        }
      }
    });

const mealBolusRecordsPollInterval = Duration(minutes: 1);

Future<List<MealBolusRecord>> readMealBolusRecords(
  DatabaseImpl db,
  int mealId, {
  Future<List<Treatment>> Function(BolusWizard)? history,
}) async {
  final wizards = await db.transaction(() async {
    final rows = <BolusWizardData>[];
    for (final link in await db.mealWizardLinkDao.forMeal(mealId)) {
      if (link.relationType == 'correction') continue;
      final wizard =
          await (db.select(db.bolusWizard)..where((row) {
                if (link.localWizardId case final id?) {
                  return row.localId.equals(id);
                }
                return row.nightscoutId.equals(link.remoteWizardId!) &
                    row.remoteSource.equals(link.remoteSource!);
              }))
              .getSingleOrNull();
      if (wizard != null) rows.add(wizard);
    }
    return rows;
  });
  final records = <MealBolusRecord>[];
  for (final row in wizards) {
    final wizard = row.toDomain();
    final live = history == null ? const <Treatment>[] : await history(wizard);
    final submission = await readMealCalculatorSubmission(
      db,
      wizard,
      liveTreatments: live,
    );
    if (!submission.isValid) continue;
    records.add((
      source: TreatmentsSource.fromStorage(row.source),
      recorded: submission.deliveredInsulin,
      recommended: submission.recommendedInsulin,
      cancelled:
          submission.delivery == null &&
          (submission.wizard.hasUnresolvedDelivery ||
              live.whereType<ManualBolus>().any(
                (bolus) =>
                    !bolus.isValid &&
                    bolus.insulin.isFinite &&
                    bolus.insulin > 0 &&
                    mealBolusDeliveryFollowsWizard(wizard, bolus) &&
                    // A later calculator before the bolus owns it instead.
                    !live.whereType<BolusWizard>().any(
                      (other) =>
                          other.createdAt.isAfter(wizard.createdAt) &&
                          !other.createdAt.isAfter(bolus.createdAt),
                    ),
              )),
    ));
  }
  return records;
}

final mealBolusShortfallsProvider = Provider.autoDispose
    .family<AsyncValue<List<MealBolusShortfall>>, int>((ref, mealId) {
      return ref
          .watch(mealBolusRecordsProvider(mealId))
          .whenData(
            (records) => [
              for (final record in records)
                if (record.recorded case final amount?)
                  if (record.recommended.isFinite &&
                      amount < record.recommended - 0.001)
                    (delivered: amount, recommended: record.recommended),
            ],
          );
    });

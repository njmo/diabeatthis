import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_sources/config/data_source_config.dart';
import '../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../core/drift/providers/database_provider.dart';
import 'meal_calculator_submission.dart';

typedef MealBolusShortfall = ({double delivered, double recommended});

typedef MealBolusRecord = ({
  TreatmentsSource source,
  double? recorded,
  double recommended,
});

final mealBolusRecordsProvider = StreamProvider.autoDispose
    .family<List<MealBolusRecord>, int>((ref, mealId) {
      final db = ref.watch(databaseProvider);
      return db
          .customSelect(
            'SELECT 1 FROM meal_wizard_link '
            'WHERE meal_id = ? AND dismissed = 0',
            variables: [Variable(mealId)],
            readsFrom: {db.mealWizardLink, db.bolusWizard, db.manualBolus},
          )
          .watch()
          .asyncMap(
            (_) => db.transaction(() async {
              final records = <MealBolusRecord>[];
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
                if (wizard == null) continue;
                final submission = await readMealCalculatorSubmission(
                  db,
                  wizard.toDomain(),
                );
                if (!submission.isValid) continue;
                records.add((
                  source: TreatmentsSource.fromStorage(wizard.source),
                  recorded: submission.deliveredInsulin,
                  recommended: submission.recommendedInsulin,
                ));
              }
              return records;
            }),
          );
    });

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

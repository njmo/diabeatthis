import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../core/drift/providers/database_provider.dart';
import 'meal_calculator_submission.dart';

typedef MealBolusShortfall = ({double delivered, double recommended});

final mealBolusShortfallsProvider = StreamProvider.autoDispose
    .family<List<MealBolusShortfall>, int>((ref, mealId) {
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
              final shortfalls = <MealBolusShortfall>[];
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
                final delivered = submission.deliveredInsulin;
                final recommended = submission.recommendedInsulin;
                if (delivered != null &&
                    recommended.isFinite &&
                    delivered < recommended - 0.001) {
                  shortfalls.add((
                    delivered: delivered,
                    recommended: recommended,
                  ));
                }
              }
              return shortfalls;
            }),
          );
    });

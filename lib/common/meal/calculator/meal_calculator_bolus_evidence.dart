import 'package:drift/drift.dart';

import '../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../core/drift/database_impl.dart';
import '../meal_calculator_submission.dart';

/// Meal/wizard links survive automatic summarization, unlike the add-on context.
Future<List<int>> readConfirmedMealCalculatorWizards(
  DatabaseImpl db,
  int mealId,
  DateTime requestedAt,
  int requiredCarbs,
) => db.transaction(() async {
  final times = <int>[];
  var carbs = 0.0;
  for (final link in await db.mealWizardLinkDao.forMeal(mealId)) {
    if (link.relationType == 'correction') continue;
    final wizard =
        await (db.select(db.bolusWizard)..where((row) {
              if (link.localWizardId != null) {
                return row.localId.equals(link.localWizardId!);
              }
              return row.nightscoutId.equals(link.remoteWizardId!) &
                  row.remoteSource.equals(link.remoteSource!);
            }))
            .getSingleOrNull();
    if (wizard == null ||
        wizard.createdAt ~/ 1000 < requestedAt.millisecondsSinceEpoch ~/ 1000) {
      continue;
    }
    final submission = await readMealCalculatorSubmission(
      db,
      wizard.toDomain(),
    );
    if (!submission.isComplete || !submission.carbs.isFinite) continue;
    times.add(wizard.createdAt);
    carbs += submission.carbs;
  }
  times.sort();
  return carbs + 0.001 >= requiredCarbs ? times : <int>[];
});

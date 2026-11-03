import 'package:drift/drift.dart';

import '../../../core/drift/database_impl.dart';
import '../meal_add_on_bolus_context.dart';
import 'meal_calculator_bolus_evidence.dart';

/// Reads durable meal evidence and projects confirmations without changing the
/// meal lifecycle. The controller owns request ordering and window observers.
class MealCalculatorStateUseCase {
  const MealCalculatorStateUseCase(this.db);

  final DatabaseImpl db;

  Future<MealAddOnBolusContext?> readContext(int id) async =>
      MealAddOnBolusContext.decode(
        (await db.mealDao.getMealById(id))?.addOnBolusContext,
      );

  Future<bool> isMealRelevant(int id) async {
    final meal = await db.mealDao.getMealById(id);
    // Summarization after ordinary carbs does not cancel pending e-carbs.
    return meal != null &&
        !const {'skipped', 'interrupted'}.contains(meal.status);
  }

  Future<List<int>> readAcceptedWizards(int id, DateTime since, int carbs) =>
      readConfirmedMealCalculatorWizards(db, id, since, carbs);

  Future<List<Map<String, dynamic>>> readCarbohydrateReceipts(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await db.localMirrorDao.getExtendedCarbsBetween(start, end);
    final treats = await db.localMirrorDao.getTreatsBetween(start, end);
    return [
      for (final row in treats)
        {
          'id': row.externalId,
          'at': row.createdAt,
          'observedAt': row.receivedAt,
          'carbs': row.carbs?.round() ?? 0,
          'duration': 0,
          'valid': true,
        },
      for (final row in rows)
        {
          'id': row.externalId,
          'at': row.createdAt,
          'observedAt': row.receivedAt,
          'carbs': row.carbs?.round() ?? 0,
          'duration': Duration(
            minutes: row.durationMinutes ?? 0,
          ).inMilliseconds,
          'valid': true,
        },
    ];
  }

  Future<void> projectExtendedConfirmation(
    int id,
    DateTime requestedAt,
    int grams,
    bool confirmed,
  ) => db.transaction(() async {
    final context = await readContext(id);
    if (context == null ||
        context.requestedAt != requestedAt ||
        context.requestedExtendedCarbs != grams ||
        context.extendedCarbsConfirmed == confirmed) {
      return;
    }
    await (db.update(db.meal)..where((row) => row.id.equals(id))).write(
      MealCompanion(
        addOnBolusContext: Value(
          context.copyWith(extendedCarbsConfirmed: confirmed).encode(),
        ),
      ),
    );
  });
}

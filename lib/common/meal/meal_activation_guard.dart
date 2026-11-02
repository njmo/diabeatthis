import 'package:drift/drift.dart';

import '../../core/domain/model/meal_status_flow.dart';
import '../../core/drift/database_impl.dart';
import '../l10n/language.dart';
import 'meal_display_name.dart';

class MealActivationException implements Exception {
  const MealActivationException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

/// Call inside the mutation's transaction before saving advice or quantities.
Future<void> ensureMealActivationAllowed(
  DatabaseImpl database,
  int mealId, {
  required Set<String> allowedStatuses,
}) async {
  final current = await database.mealDao.getMealById(mealId);
  if (current == null ||
      current.purpose != 'meal' ||
      current.status == 'interrupted' ||
      !allowedStatuses.contains(current.status)) {
    throw MealActivationException(lang.mealCompletionStale);
  }
  final blocking =
      await (database.select(database.meal)
            ..where((row) => row.id.equals(mealId).not())
            ..where((row) => row.purpose.equals('meal'))
            ..where(
              (row) => row.status.isIn(
                mealStatusesBlockingAnotherMealActivation.toList(
                  growable: false,
                ),
              ),
            )
            ..limit(1))
          .getSingleOrNull();
  if (blocking != null) {
    throw MealActivationException(
      lang.mealStatusActivationBlocked(mealDisplayName(blocking.name)),
    );
  }
}

import '../../../../core/drift/database_impl.dart';

typedef RecordedMealIngredientAmounts = ({
  IngredientData ingredient,
  double gramsPerPortion,
  bool conversionAvailable,
  double plannedAmount,
  double plannedGrams,
  double consumedGrams,
});

/// Shared interpretation of stored meal amounts, including legacy portion fallback.
class MealIngredientAmountsRepository {
  final DatabaseImpl db;
  const MealIngredientAmountsRepository(this.db);

  Future<RecordedMealIngredientAmounts> load(MealIngredient entry) async {
    final ingredient = await db.ingredientDao.getIngredientById(
      entry.ingredientId,
    );
    // SQLite RETURNING is evaluated before AFTER INSERT capture triggers. Read
    // only the immutable derived factor back; caller-supplied quantities stay intact.
    final storedConversion =
        entry.gramsPerPortionUsed ??
        (await (db.select(
              db.mealIngredients,
            )..where((row) => row.id.equals(entry.id))).getSingleOrNull())
            ?.gramsPerPortionUsed;
    final conversionAvailable =
        storedConversion != null ||
        ingredient.isReference == 1 ||
        entry.portionId == null;
    final gramsPerPortion =
        storedConversion ??
        (ingredient.isReference == 1
            ? 100.0
            : entry.portionId == null
            ? 1.0
            : 0.0);
    final plannedAmount = entry.entryType == 'extra' ? 0.0 : entry.amount;
    final consumedAmount = entry.consumedAmount ?? plannedAmount;
    return (
      ingredient: ingredient,
      conversionAvailable: conversionAvailable,
      gramsPerPortion: gramsPerPortion,
      plannedAmount: plannedAmount,
      plannedGrams: plannedAmount * gramsPerPortion,
      consumedGrams: consumedAmount * gramsPerPortion,
    );
  }
}

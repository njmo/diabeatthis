import '../../../../core/drift/database_impl.dart';

typedef RecordedMealIngredientAmounts = ({
  IngredientData ingredient,
  double gramsPerPortion,
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
    final gramsPerPortion = ingredient.isReference == 1
        ? 100.0
        : entry.portionId == null
        ? 1.0
        : await db.portionDao.getGramsPerPortion(
                ingredient.id,
                entry.portionId!,
              ) ??
              1.0;
    final plannedAmount = entry.entryType == 'extra' ? 0.0 : entry.amount;
    final consumedAmount = entry.consumedAmount ?? plannedAmount;
    return (
      ingredient: ingredient,
      gramsPerPortion: gramsPerPortion,
      plannedAmount: plannedAmount,
      plannedGrams: plannedAmount * gramsPerPortion,
      consumedGrams: consumedAmount * gramsPerPortion,
    );
  }
}

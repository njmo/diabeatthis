import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'ingredient_dao.g.dart';

class MealSummary {
  final double carbsG;
  final double proteinKcal;
  final double fatKcal;
  final double fatGrams;
  final double proteinGrams;
  final double fiberGrams;

  MealSummary({
    required this.carbsG,
    required this.proteinKcal,
    required this.fatKcal,
    required this.fatGrams,
    required this.proteinGrams,
    required this.fiberGrams,
  });
}

@DriftAccessor(include: {'../schemas/tables/ingredient.drift'})
class IngredientDao extends DatabaseAccessor<DatabaseImpl>
    with _$IngredientDaoMixin {
  IngredientDao(super.db);

  Future<List<IngredientData>> getIngredientsInMeal(int mealId) {
    final query = select(db.ingredient).join([
      innerJoin(db.mealIngredients, db.mealIngredients.mealId.equals(mealId)),
    ])..where(db.mealIngredients.mealId.equals(mealId));

    return query.map((row) => row.readTable(db.ingredient)).get();
  }

  Future<MealSummary?> totalsForMeal(int mealId) async {
    final mi = db.mealIngredients;
    final ing = ingredient;
    final ip = db.ingredientPortions;

    final base = select(mi).join([
      innerJoin(ing, ing.id.equalsExp(mi.ingredientId)),
      leftOuterJoin(
        ip,
        ip.ingredientId.equalsExp(mi.ingredientId) &
            ip.portionId.equalsExp(mi.portionId),
      ),
    ])..where(mi.mealId.equals(mealId));

    final grams = CaseWhenExpression<double>(
      cases: [
        CaseWhen(
          ing.isReference.equals(1),
          then: mi.amount.cast<double>() * const Constant(100.0),
        ),
        CaseWhen(
          mi.portionId.isNull(),
          then: mi.amount.cast<double>(),
        ),
      ],
      orElse: mi.amount.cast<double>() * ip.gramsPerPortion.cast<double>(),
    );

    final carbsG = (grams * ing.carbsPer100g / const Constant(100.0)).sum();
    // final fiberG = (grams * ing.fiberPer100g / const Constant(100.0)).sum();
    final proteinKcal =
        (grams *
                ing.proteinPer100g /
                const Constant(100.0) *
                const Constant(4.0))
            .sum();
    final fatKcal =
        (grams * ing.fatPer100g / const Constant(100.0) * const Constant(9.0))
            .sum();

    final q = base
      ..addColumns([mi.mealId, carbsG, proteinKcal, fatKcal])
      ..groupBy([mi.mealId]);

    final row = await q.getSingleOrNull();
    if (row == null) return null;

    return MealSummary(
      carbsG: row.read(carbsG) ?? 0.0,
      proteinKcal: row.read(proteinKcal) ?? 0.0,
      fatKcal: row.read(fatKcal) ?? 0.0,
      fatGrams: row.read(ing.fatPer100g) ?? 0.0,
      proteinGrams: row.read(ing.proteinPer100g) ?? 0.0,
      fiberGrams: row.read(ing.fiberPer100g) ?? 0.0,
    );
  }
}

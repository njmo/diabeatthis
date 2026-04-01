import 'package:drift/drift.dart';
import '../../domain/model/meal_macro_summary.dart';
import '../database_impl.dart';

part 'ingredient_dao.g.dart';

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

  Future<IngredientData> getIngredientById(int id) {
    final query = select(db.ingredient)..where((tbl) => tbl.id.equals(id));

    return query.getSingle();
  }

  Future<MealMacroSummary?> totalsForMealConsumed(int mealId) async {
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

    final effectiveAmount = CaseWhenExpression<double>(
      cases: [
        CaseWhen(
          mi.entryType.equals('extra'),
          then: CaseWhenExpression<double>(
            cases: [
              CaseWhen(mi.consumedAmount.isNull(), then: const Constant(0.0)),
            ],
            orElse: mi.consumedAmount.cast<double>(),
          ),
        ),
      ],
      orElse: CaseWhenExpression<double>(
        cases: [
          CaseWhen(mi.consumedAmount.isNull(), then: mi.amount.cast<double>()),
        ],
        orElse: mi.consumedAmount.cast<double>(),
      ),
    );

    final grams = CaseWhenExpression<double>(
      cases: [
        CaseWhen(
          ing.isReference.equals(1),
          then: effectiveAmount * const Constant(100.0),
        ),
        CaseWhen(mi.portionId.isNull(), then: effectiveAmount),
      ],
      orElse: effectiveAmount * ip.gramsPerPortion.cast<double>(),
    );

    final totalGrams = grams.sum();
    final carbsG = (grams * ing.carbsPer100g / const Constant(100.0)).sum();
    final fiberG = (grams * ing.fiberPer100g / const Constant(100.0)).sum();
    final proteinG = (grams * ing.proteinPer100g / const Constant(100.0)).sum();
    final fatG = (grams * ing.fatPer100g / const Constant(100.0)).sum();

    final q = base
      ..addColumns([mi.mealId, carbsG, fiberG, proteinG, fatG, totalGrams])
      ..groupBy([mi.mealId]);

    final row = await q.getSingleOrNull();
    if (row == null) return null;

    return MealMacroSummary(
      carbsGrams: row.read(carbsG) ?? 0.0,
      fatGrams: row.read(fatG) ?? 0.0,
      proteinGrams: row.read(proteinG) ?? 0.0,
      fiberGrams: row.read(fiberG) ?? 0.0,
      totalGrams: row.read(totalGrams) ?? 0.0,
    );
  }

  Future<MealMacroSummary?> totalsForMeal(int mealId) async {
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
        CaseWhen(mi.portionId.isNull(), then: mi.amount.cast<double>()),
      ],
      orElse: mi.amount.cast<double>() * ip.gramsPerPortion.cast<double>(),
    );

    final totalGrams = grams.sum();
    final carbsG = (grams * ing.carbsPer100g / const Constant(100.0)).sum();
    final fiberG = (grams * ing.fiberPer100g / const Constant(100.0)).sum();
    final proteinG = (grams * ing.proteinPer100g / const Constant(100.0)).sum();
    final fatG = (grams * ing.fatPer100g / const Constant(100.0)).sum();

    final q = base
      ..addColumns([mi.mealId, carbsG, fiberG, proteinG, fatG, totalGrams])
      ..groupBy([mi.mealId]);

    final row = await q.getSingleOrNull();
    if (row == null) return null;

    return MealMacroSummary(
      carbsGrams: row.read(carbsG) ?? 0.0,
      fatGrams: row.read(fatG) ?? 0.0,
      proteinGrams: row.read(proteinG) ?? 0.0,
      fiberGrams: row.read(fiberG) ?? 0.0,
      totalGrams: row.read(totalGrams) ?? 0.0,
    );
  }
}

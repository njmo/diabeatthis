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

  Stream<List<IngredientData>> watchIngredients({int? limit}) {
    final query = select(db.ingredient)
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]);
    if (limit != null) {
      query.limit(limit);
    }

    return query.watch();
  }

  Stream<List<IngredientData>> watchIngredientsByQuery({
    required String queryString,
    required int limit,
  }) {
    final normalizedQuery = _normalizeSearchTerm(queryString);
    final query = select(db.ingredient)
      ..where(
        (tbl) =>
            tbl.name.like('%$normalizedQuery%') |
            tbl.brand.like('%$normalizedQuery%'),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
      ..limit(limit);

    return query.watch();
  }

  Future<List<IngredientData>> getLatestIngredients({int limit = 10}) {
    final query = select(db.ingredient)
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    return query.get();
  }

  Future<List<IngredientData>> searchIngredientsByNamesOrBrand({
    required List<String> names,
    required String? brand,
    required int limit,
  }) {
    final normalizedNames = names
        .map(_normalizeSearchTerm)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final normalizedBrand = _normalizeSearchTerm(brand ?? '');

    if (normalizedNames.isEmpty && normalizedBrand.isEmpty) {
      return Future.value(const []);
    }

    final query = select(db.ingredient)
      ..where((tbl) {
        Expression<bool>? condition;

        void addCondition(Expression<bool> expression) {
          condition = condition == null ? expression : condition! | expression;
        }

        for (final name in normalizedNames) {
          addCondition(tbl.name.like('%$name%'));
        }

        if (normalizedBrand.isNotEmpty) {
          addCondition(tbl.brand.like('%$normalizedBrand%'));
        }

        return condition ?? const Constant(false);
      })
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])
      ..limit(limit);

    return query.get();
  }

  Future<List<IngredientStatusHistoryData>> getIngredientStatusHistory(
    int ingredientId,
  ) {
    final query = select(ingredientStatusHistory)
      ..where((tbl) => tbl.ingredientId.equals(ingredientId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

    return query.get();
  }

  Future<void> updateIngredientDetails({
    required int ingredientId,
    required String name,
    required double carbsPer100g,
    required double fatPer100g,
    required double fiberPer100g,
    required double proteinPer100g,
    required double nutritionConfidence,
    required bool isReference,
    required String? brand,
  }) async {
    final updatedRows =
        await (update(
          ingredient,
        )..where((tbl) => tbl.id.equals(ingredientId))).write(
          IngredientCompanion(
            name: Value(name),
            carbsPer100g: Value(carbsPer100g),
            fatPer100g: Value(fatPer100g),
            fiberPer100g: Value(fiberPer100g),
            proteinPer100g: Value(proteinPer100g),
            nutritionConfidence: Value(nutritionConfidence),
            isReference: Value(isReference ? 1 : 0),
            brand: Value(brand),
          ),
        );

    if (updatedRows == 0) {
      throw StateError('Ingredient $ingredientId was not found');
    }
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

String _normalizeSearchTerm(String value) => value.trim().toLowerCase();

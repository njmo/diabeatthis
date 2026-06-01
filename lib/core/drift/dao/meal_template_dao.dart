import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_template_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal_template.drift'})
class MealTemplateDao extends DatabaseAccessor<DatabaseImpl>
    with _$MealTemplateDaoMixin {
  MealTemplateDao(super.db);

  Future<List<MealTemplateData>> searchRecentMealTemplates() {
    final query = select(db.mealTemplate)
      ..orderBy([
        (m) => OrderingTerm(expression: m.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(10);

    return query.get();
  }

  Future<List<MealTemplateData>> searchMealTemplatesByName(String queryString) {
    final normalizedQuery = queryString.trim();
    final query = select(db.mealTemplate)
      ..where((tbl) => tbl.name.like('%$normalizedQuery%'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(10);

    return query.get();
  }

  Future<List<MealTemplateData>> searchMealTemplatesByIngredientIds({
    required List<int> ingredientIds,
  }) {
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    final distinctIngredientCount = db.mealTemplateIngredients.ingredientId
        .count(distinct: true);
    final query =
        select(db.mealTemplate).join([
            innerJoin(
              db.mealTemplateIngredients,
              db.mealTemplateIngredients.mealTemplateId.equalsExp(
                db.mealTemplate.id,
              ),
            ),
          ])
          ..where(
            db.mealTemplateIngredients.ingredientId.isIn(distinctIngredientIds),
          )
          ..groupBy([db.mealTemplate.id])
          ..orderBy([
            OrderingTerm(
              expression: distinctIngredientCount,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: db.mealTemplate.updatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(10);

    return query.map((row) => row.readTable(db.mealTemplate)).get();
  }

  Future<List<MealTemplateData>> searchMealTemplatesByNameAndIngredientIds({
    required String queryString,
    required List<int> ingredientIds,
  }) {
    final normalizedQuery = queryString.trim();
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    final distinctIngredientCount = db.mealTemplateIngredients.ingredientId
        .count(distinct: true);
    final query =
        select(db.mealTemplate).join([
            innerJoin(
              db.mealTemplateIngredients,
              db.mealTemplateIngredients.mealTemplateId.equalsExp(
                db.mealTemplate.id,
              ),
            ),
          ])
          ..where(db.mealTemplate.name.like('%$normalizedQuery%'))
          ..where(
            db.mealTemplateIngredients.ingredientId.isIn(distinctIngredientIds),
          )
          ..groupBy([db.mealTemplate.id])
          ..orderBy([
            OrderingTerm(
              expression: distinctIngredientCount,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: db.mealTemplate.updatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(10);

    return query.map((row) => row.readTable(db.mealTemplate)).get();
  }
}

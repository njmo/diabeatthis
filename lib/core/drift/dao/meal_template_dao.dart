import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_template_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal_template.drift'})
class MealTemplateDao extends DatabaseAccessor<DatabaseImpl> with _$MealTemplateDaoMixin {
  MealTemplateDao(super.db);

  Future<List<MealTemplateData>> searchMealTemplatesByName(String queryString) {
    final query = select(db.mealTemplate)
      ..where((tbl) => tbl.name.like('%$queryString%'))
      ..orderBy([(m) => OrderingTerm(expression: m.updatedAt)])
      ..limit(10);

    return query.get();
  }
}

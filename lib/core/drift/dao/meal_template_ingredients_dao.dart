import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_template_ingredients_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal_template_ingredients.drift'})
class MealTemplateIngredientsDao extends DatabaseAccessor<DatabaseImpl> with _$MealTemplateIngredientsDaoMixin {
  MealTemplateIngredientsDao(super.db);


  Future<List<MealTemplateIngredient>> getMealTemplateIngredientsForMeal(int mealTemplateId) async {
    final ingredients = db.select(db.mealTemplateIngredients)..where((tbl) => tbl.mealTemplateId.equals(mealTemplateId));
    return ingredients.get();
  }
}

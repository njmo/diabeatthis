

import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_ingredients_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal_ingredients.drift'})
class MealIngredientsDao extends DatabaseAccessor<DatabaseImpl> with _$MealIngredientsDaoMixin {
  MealIngredientsDao(super.db);

  Future<List<MealIngredient>> getMealIngredientsForMeal(int mealId) async {
    final ingredients = db.select(db.mealIngredients)..where((tbl) => tbl.mealId.equals(mealId));
    return ingredients.get();
  }
}

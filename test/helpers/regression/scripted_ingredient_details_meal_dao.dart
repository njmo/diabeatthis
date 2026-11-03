import 'package:diabeatthis/core/drift/dao/meal_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedIngredientDetailsMealDao extends Fake implements MealDao {
  final ScriptedRead<List<MealData>> meals;
  ScriptedIngredientDetailsMealDao(this.meals);
  @override
  Future<List<MealData>> getMealsForIngredient(int id) => meals([id]);
}

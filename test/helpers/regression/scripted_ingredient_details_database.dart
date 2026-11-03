import 'package:diabeatthis/core/drift/dao/ingredient_dao.dart';
import 'package:diabeatthis/core/drift/dao/meal_dao.dart';
import 'package:diabeatthis/core/drift/dao/portion_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptedIngredientDetailsDatabase extends Fake implements DatabaseImpl {
  @override
  final IngredientDao ingredientDao;
  @override
  final PortionDao portionDao;
  @override
  final MealDao mealDao;
  ScriptedIngredientDetailsDatabase(
    this.ingredientDao,
    this.portionDao,
    this.mealDao,
  );
}

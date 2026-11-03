import 'package:diabeatthis/core/drift/dao/meal_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptedMealDatabase extends Fake implements DatabaseImpl {
  @override
  final MealDao mealDao;
  ScriptedMealDatabase(this.mealDao);
}

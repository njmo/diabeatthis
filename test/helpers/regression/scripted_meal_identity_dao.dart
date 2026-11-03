import 'package:diabeatthis/core/drift/dao/meal_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedMealIdentityDao extends Fake implements MealDao {
  final ScriptedRead<MealData?> reads;
  ScriptedMealIdentityDao(this.reads);

  @override
  Future<MealData?> getMealById(int id) => reads([id]);
}

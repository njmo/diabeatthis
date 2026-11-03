import 'package:diabeatthis/core/drift/dao/meal_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedMealDao extends Fake implements MealDao {
  final ScriptedRead<List<MealData>> reads;
  ScriptedMealDao(this.reads);
  @override
  Stream<List<MealData>> watchRecentMeals({
    required int limit,
    String? category,
  }) => Stream.fromFuture(reads(['recent', limit, category]));
  @override
  Stream<List<MealData>> watchMealsByName({
    required String queryString,
    required int limit,
    String? category,
  }) => Stream.fromFuture(reads(['name', queryString, limit, category]));
  @override
  Stream<List<MealData>> watchMealsByIngredientIds({
    required List<int> ingredientIds,
    required int limit,
    String? category,
  }) =>
      Stream.fromFuture(reads(['ingredients', ingredientIds, limit, category]));
  @override
  Stream<List<MealData>> watchMealsByNameAndIngredientIds({
    required String queryString,
    required List<int> ingredientIds,
    required int limit,
    String? category,
  }) => Stream.fromFuture(
    reads(['combined', queryString, ingredientIds, limit, category]),
  );
}

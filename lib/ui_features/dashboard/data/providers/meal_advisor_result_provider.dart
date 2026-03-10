import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/drift/providers/database_provider.dart';
import '../utils/meal_advisor.dart';

part 'meal_advisor_result_provider.g.dart';

@riverpod
void insertAdvice(Ref ref, domain.Meal meal, MealAdvice advice)
{
  final db = ref.watch(databaseProvider);
  db.mealAdvisorResultDao.insertMealAdvisorResult(meal.id, advice);
}

@riverpod
Future<MealAdvice?> getMealAdvice(Ref ref, domain.Meal meal)
async {
  final db = ref.watch(databaseProvider);
  return await db.mealAdvisorResultDao.getMealAdvisorResult(meal.id);
}
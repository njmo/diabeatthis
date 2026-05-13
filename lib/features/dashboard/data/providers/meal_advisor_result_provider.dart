import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/drift/providers/database_provider.dart';
import '../repositories/meal_advisor_result_store.dart';
import '../use_cases/meal_advisor_result_use_case.dart';
import '../utils/meal_advisor.dart';

part 'meal_advisor_result_provider.g.dart';

@riverpod
void insertAdvice(Ref ref, domain.Meal meal, MealAdvice advice) {
  final db = ref.watch(databaseProvider);
  MealAdvisorResultUseCase(
    DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
  ).saveMealAdvice(meal.id, advice);
}

@riverpod
void updateFinalWaitTime(Ref ref, domain.Meal meal, int finalWaitTime) {
  final db = ref.watch(databaseProvider);
  db.mealAdvisorResultDao.updateAdvisorResultFinalWaitTime(
    meal.id,
    finalWaitTime,
  );
}

@riverpod
Future<MealAdvice?> getMealAdvice(Ref ref, domain.Meal meal) async {
  final db = ref.watch(databaseProvider);
  return await MealAdvisorResultUseCase(
    DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
  ).loadMealAdvice(meal.id);
}

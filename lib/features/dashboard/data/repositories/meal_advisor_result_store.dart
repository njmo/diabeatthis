import '../../../../core/drift/dao/meal_advisor_result_dao.dart';
import '../../../../core/drift/mappers/meal_advisor_result_drift_mapper.dart';
import '../models/persisted_meal_advisor_result.dart';

abstract interface class MealAdvisorResultStore {
  Future<PersistedMealAdvisorResult?> getMealAdvisorResult(int mealId);

  Future<int> insertMealAdvisorResult(PersistedMealAdvisorResult result);
}

class DriftMealAdvisorResultStore implements MealAdvisorResultStore {
  final MealAdvisorResultDao dao;
  final MealAdvisorResultDriftMapper mapper;

  const DriftMealAdvisorResultStore({
    required this.dao,
    this.mapper = const MealAdvisorResultDriftMapper(),
  });

  @override
  Future<PersistedMealAdvisorResult?> getMealAdvisorResult(int mealId) async {
    final result = await dao.getMealAdvisorResult(mealId);
    if (result == null) return null;
    return mapper.fromData(result);
  }

  @override
  Future<int> insertMealAdvisorResult(PersistedMealAdvisorResult result) {
    return dao.insertMealAdvisorResult(mapper.toCompanion(result));
  }
}

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';

part 'low_treatment_related_meal_provider.g.dart';

const lowTreatmentRelatedMealWindow = Duration(hours: 3);

@riverpod
Future<Meal?> lowTreatmentRelatedMealCandidate(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final meal = await db.mealDao.getLatestMealBefore(
    clock.now(),
    maxAge: lowTreatmentRelatedMealWindow,
  );
  return meal?.toDomain();
}

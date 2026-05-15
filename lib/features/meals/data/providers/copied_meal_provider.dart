import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../mapper/copied_meal_type_mapper.dart';
import '../model/copied_meal_type.dart';

part 'copied_meal_provider.g.dart';

@riverpod
Future<List<CopiedMealType>> copiedFromMealByQuery(
  Ref ref,
  String query,
) async {
  final db = ref.watch(databaseProvider);
  final meals = await db.mealDao.searchMealsByName(query);
  return meals.map((e) => e.toCopiedMealType()).toList();
}

@riverpod
Future<List<CopiedMealType>> copiedFromMealTemplateByQuery(
  Ref ref,
  String query,
) async {
  final db = ref.watch(databaseProvider);
  final meals = await db.mealTemplateDao.searchMealTemplatesByName(query);
  return meals.map((e) => e.toCopiedMealType()).toList();
}

@riverpod
Future<int?> copiedMealPreviewTarget(Ref ref, CopiedMealType copiedMeal) async {
  final db = ref.watch(databaseProvider);
  final meal = await db.mealDao.getLatestMealForCopySource(
    baseMealId: copiedMeal.previewBaseMealId,
    mealTemplateId: copiedMeal.previewTemplateId,
  );
  return meal?.id;
}

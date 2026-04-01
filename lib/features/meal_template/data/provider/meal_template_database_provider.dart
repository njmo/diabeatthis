import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/meal_template.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/meal_template_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../drafts/template_meal_draft.dart';
import '../mapper/meal_template_draft_drift_mapper.dart';

part 'meal_template_database_provider.g.dart';

@riverpod
void updateTemplateMeal(Ref ref, domain.MealTemplate meal, String status) {
  final db = ref.watch(databaseProvider);
  db.mealDao.updateMealStatus(meal.id, status);
}

@riverpod
void updateMealTemplateById(Ref ref, int mealId, String status) {
  final db = ref.watch(databaseProvider);
  db.mealDao.updateMealStatus(mealId, status);
}

@riverpod
Stream<List<domain.MealTemplate>> mealsTemplateStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.allMealTemplates().watch().map((e) => e.toDomainList());
}

@riverpod
Future<void> insertMealTemplateIngredient(
  Ref ref,
  domain.Ingredient ingredient,
  domain.MealTemplate meal,
  domain.Portion? portion,
  double amount,
  double nutritionConfidence,
    bool isOptional,
) async {
  final db = ref.watch(databaseProvider);
  final ingredientId = ingredient.map(
    existing: (e) => e.id,
    draft: (_) => throw Exception('Cannot get id for draft'),
  );
  await db.insertMealTemplateIngredient(
    meal.id,
    ingredientId,
    portion?.id,
    amount,
    isOptional,
    nutritionConfidence,
    null,
    null,
    false
  );
}

@riverpod
Future<domain.MealTemplate> insertMealTemplate(Ref ref, MealTemplateDraft meal) async {
  final db = ref.watch(databaseProvider);
  final value = await db
      .into(db.mealTemplate)
      .insertReturningOrNull(meal.toCompanion());
  if (value != null) {
    return value.toDomain();
  } else {
    throw Exception('Could not insert meal template');
  }
}

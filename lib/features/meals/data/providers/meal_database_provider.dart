import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../drafts/meal_draft.dart';
import '../mapper/meal_draft_mapper.dart';

part 'meal_database_provider.g.dart';

@riverpod
Stream<List<domain.Meal>> mealsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.allMeals().watch().map(
        (e) => e.toDomainList(),
  );
}

@riverpod
Future<void> insertMealIngredient(Ref ref, domain.Ingredient ingredient, domain.Meal meal, domain.Portion portion, int amount) async {
  final db = ref.watch(databaseProvider);
  await db.insertMealIngredient(
    ingredient.id,
    portion.id,
    meal.id,
    amount,
    null,
    null,
    null,
  );
}

@riverpod
Future<domain.Meal> insertMeal(Ref ref, MealDraft meal) async
{
  final db = ref.watch(databaseProvider);
  final value = await db.into(db.meal).insertReturningOrNull(meal.toCompanion());
  if(value != null)
    {
      return value.toDomain();
    }
  else
    {
      throw Exception('Could not insert meal');
    }
}

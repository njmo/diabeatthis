import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../drafts/meal_draft.dart';
import '../mapper/meal_draft_drift_mapper.dart';

Future<domain.Meal> insertMealDraft(DatabaseImpl db, MealDraft meal) async {
  final value = await db
      .into(db.meal)
      .insertReturningOrNull(meal.toCompanion());
  if (value != null) {
    return value.toDomain();
  } else {
    throw Exception('Could not insert meal');
  }
}

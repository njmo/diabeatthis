import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_category.dart';
import '../../../../../common/meal/meal_name_formatter.dart';
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';

class UpdateMealCategoryUseCase {
  const UpdateMealCategoryUseCase(this.ref);
  final Ref ref;

  Future<MealCategory?> load(int mealId) async {
    final meal = await ref.read(databaseProvider).mealDao.getMealById(mealId);
    if (meal == null) throw StateError('Meal does not exist');
    return MealCategory.fromStorage(meal.category);
  }

  Future<void> call(
    int mealId,
    MealCategory category,
    AppLocalizations language,
  ) async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      final current = await db.mealDao.getMealById(mealId);
      if (current == null) throw StateError('Meal does not exist');
      final name = recategorizeMealName(language, current.name, category);
      await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
        MealCompanion(category: Value(category.name), name: Value(name)),
      );
    });
  }
}

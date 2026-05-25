import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../mappers/meal_details_data_mapper.dart';
import '../../models/meal_details_data.dart';

part 'load_meal_details_use_case.g.dart';

@Riverpod(keepAlive: true)
LoadMealDetailsUseCase loadMealDetailsUseCase(Ref ref) {
  return LoadMealDetailsUseCase(ref: ref);
}

class LoadMealDetailsUseCase {
  final Ref ref;

  const LoadMealDetailsUseCase({required this.ref});

  Future<MealDetailsData> call(int mealId) async {
    final db = ref.read(databaseProvider);
    final mapper = MealDetailsDataMapper(db: db);
    final meal = await db.mealDao.getMealById(mealId);
    if (meal == null) {
      throw StateError('Meal $mealId was not found');
    }

    final snapshots = await (db.select(
      db.mealSnapshot,
    )..where((tbl) => tbl.mealId.equals(mealId))).get();
    final plannedSnapshot = snapshots
        .where((snapshot) => snapshot.snapshotType == 'planned')
        .firstOrNull;
    final consumedSnapshot = snapshots
        .where((snapshot) => snapshot.snapshotType == 'consumed')
        .firstOrNull;

    final mealIngredients = await db.mealIngredientsDao
        .getMealIngredientsForMeal(mealId);
    final ingredientDetails = <MealIngredientDetailsData>[];
    for (final mealIngredient in mealIngredients) {
      ingredientDetails.add(
        await mapper.mapIngredient(
          meal: meal,
          mealIngredient: mealIngredient,
          plannedSnapshot: plannedSnapshot,
          consumedSnapshot: consumedSnapshot,
        ),
      );
    }

    final advisorDecision = await (db.select(
      db.mealAdvisorResult,
    )..where((tbl) => tbl.mealId.equals(mealId))).getSingleOrNull();
    final statusHistory =
        await (db.select(db.mealStatusHistory)
              ..where((tbl) => tbl.mealId.equals(mealId))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
            .get();
    final copySource = await _loadCopySource(db, meal);
    final copyUsages = await _loadCopyUsages(db, meal);

    return MealDetailsData(
      meal: mapper.mapMeal(meal),
      advisorDecision: advisorDecision == null
          ? null
          : mapper.mapAdvisorDecision(advisorDecision),
      ingredients: ingredientDetails,
      plannedSnapshot: plannedSnapshot == null
          ? null
          : mapper.mapSnapshot(plannedSnapshot),
      consumedSnapshot: consumedSnapshot == null
          ? null
          : mapper.mapSnapshot(consumedSnapshot),
      statusHistory: statusHistory.map(mapper.mapStatusHistory).toList(),
      copySource: copySource,
      copyUsages: copyUsages,
    );
  }

  Future<MealCopySourceData?> _loadCopySource(
    DatabaseImpl db,
    MealData meal,
  ) async {
    final basedOnMealId = meal.basedOnMealId;
    if (basedOnMealId == null) {
      return null;
    }

    final source = await db.mealDao.getMealById(basedOnMealId);
    if (source == null) {
      return null;
    }
    return MealCopySourceData(id: source.id, name: source.name);
  }

  Future<List<MealCopyUsageData>> _loadCopyUsages(
    DatabaseImpl db,
    MealData meal,
  ) async {
    final usages = <int, MealCopyUsageData>{};

    final directCopies = await db.mealDao.getMealsBasedOnMeal(meal.id);
    for (final copy in directCopies) {
      if (copy.id == meal.id) {
        continue;
      }
      usages[copy.id] = _mapCopyUsage(copy, 'Kopia posiłku');
    }

    final templates = await (db.select(
      db.mealTemplate,
    )..where((tbl) => tbl.createdFromMealId.equals(meal.id))).get();
    final templateIds = templates.map((template) => template.id).toSet();
    if (templateIds.isNotEmpty) {
      final templateMeals =
          await (db.select(db.meal)
                ..where((tbl) => tbl.mealTemplateId.isIn(templateIds))
                ..orderBy([
                  (tbl) => OrderingTerm(
                    expression: tbl.plannedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      for (final copy in templateMeals) {
        if (copy.id == meal.id) {
          continue;
        }
        usages[copy.id] = _mapCopyUsage(copy, 'Z szablonu');
      }
    }

    final sorted = usages.values.toList()
      ..sort((a, b) => b.plannedAt.compareTo(a.plannedAt));
    return sorted;
  }

  MealCopyUsageData _mapCopyUsage(MealData meal, String sourceType) {
    return MealCopyUsageData(
      id: meal.id,
      name: meal.name,
      plannedAt: _date(meal.plannedAt),
      status: meal.status,
      sourceType: sourceType,
    );
  }

  DateTime _date(int millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }
}

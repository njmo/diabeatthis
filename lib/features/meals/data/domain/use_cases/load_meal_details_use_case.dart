import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';
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
        await _mapIngredient(
          db: db,
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

    return MealDetailsData(
      meal: _mapMeal(meal),
      advisorDecision: advisorDecision == null
          ? null
          : _mapAdvisorDecision(advisorDecision),
      ingredients: ingredientDetails,
      plannedSnapshot: plannedSnapshot == null
          ? null
          : _mapSnapshot(plannedSnapshot),
      consumedSnapshot: consumedSnapshot == null
          ? null
          : _mapSnapshot(consumedSnapshot),
      statusHistory: statusHistory.map(_mapStatusHistory).toList(),
    );
  }

  Future<MealIngredientDetailsData> _mapIngredient({
    required DatabaseImpl db,
    required MealData meal,
    required MealIngredient mealIngredient,
    required MealSnapshotData? plannedSnapshot,
    required MealSnapshotData? consumedSnapshot,
  }) async {
    final ingredient = await db.ingredientDao.getIngredientById(
      mealIngredient.ingredientId,
    );
    final history = await db.ingredientDao.getIngredientStatusHistory(
      ingredient.id,
    );
    final gramsPerPortion = await _gramsPerPortion(
      db,
      ingredientId: ingredient.id,
      portionId: mealIngredient.portionId,
      isReference: ingredient.isReference == 1,
    );
    final portionLabel = await _portionLabel(
      db,
      portionId: mealIngredient.portionId,
      gramsPerPortion: gramsPerPortion,
      isReference: ingredient.isReference == 1,
    );

    final mealCreatedAt = _date(meal.createdAt);
    final plannedReference = plannedSnapshot == null
        ? mealCreatedAt
        : _date(plannedSnapshot.createdAt);
    final consumedReference = consumedSnapshot == null
        ? _date(mealIngredient.createdAt)
        : _date(consumedSnapshot.createdAt);
    final currentNutrition = _currentNutrition(ingredient);
    final plannedVersion = _nutritionAt(
      ingredient: ingredient,
      history: history,
      reference: plannedReference,
    );
    final consumedVersion = _nutritionAt(
      ingredient: ingredient,
      history: history,
      reference: consumedReference,
    );
    final plannedAmount = mealIngredient.entryType == 'extra'
        ? 0.0
        : mealIngredient.amount;
    final consumedAmount = mealIngredient.entryType == 'extra'
        ? (mealIngredient.consumedAmount ?? 0)
        : (mealIngredient.consumedAmount ?? mealIngredient.amount);

    return MealIngredientDetailsData(
      mealIngredientId: mealIngredient.id,
      ingredientId: ingredient.id,
      ingredientName: ingredient.name,
      entryType: mealIngredient.entryType,
      portionLabel: portionLabel,
      plannedAmount: plannedAmount,
      consumedAmount: mealIngredient.consumedAmount,
      quantityConfidence: mealIngredient.quantityConfidence,
      consumedConfidence: mealIngredient.consumedConfidence,
      plannedTotalGrams: plannedAmount * gramsPerPortion,
      consumedTotalGrams: consumedAmount * gramsPerPortion,
      prepMethod: mealIngredient.prepMethod,
      notes: mealIngredient.notes,
      createdAt: _date(mealIngredient.createdAt),
      updatedAt: _date(mealIngredient.updatedAt),
      currentNutrition: currentNutrition,
      plannedNutrition: plannedVersion.nutrition,
      consumedNutrition: consumedVersion.nutrition,
      plannedNutritionDiffersFromCurrent: plannedVersion.nutrition.differsFrom(
        currentNutrition,
      ),
      consumedNutritionDiffersFromCurrent: consumedVersion.nutrition
          .differsFrom(currentNutrition),
      historicalNutritionUnavailable:
          plannedVersion.historicalUnavailable ||
          consumedVersion.historicalUnavailable,
    );
  }

  Future<double> _gramsPerPortion(
    DatabaseImpl db, {
    required int ingredientId,
    required int? portionId,
    required bool isReference,
  }) async {
    if (isReference) {
      return 100;
    }
    if (portionId == null) {
      return 1;
    }
    return await db.portionDao.getGramsPerPortion(ingredientId, portionId) ?? 1;
  }

  Future<String> _portionLabel(
    DatabaseImpl db, {
    required int? portionId,
    required double gramsPerPortion,
    required bool isReference,
  }) async {
    if (isReference) {
      return '100g reference';
    }
    if (portionId == null) {
      return '1g';
    }
    final portion = await db.portionDao.getPortionById(portionId);
    return '${portion.name} (${_formatNumber(gramsPerPortion)}g)';
  }

  _ResolvedNutrition _nutritionAt({
    required IngredientData ingredient,
    required List<IngredientStatusHistoryData> history,
    required DateTime reference,
  }) {
    final sorted = history.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    IngredientStatusHistoryData? selected;
    for (final entry in sorted) {
      if (_date(entry.createdAt).isAfter(reference)) {
        break;
      }
      selected = entry;
    }

    if (selected != null) {
      return _ResolvedNutrition(
        nutrition: IngredientNutritionData(
          carbsPer100g: selected.carbsPer100g,
          fatPer100g: selected.fatPer100g,
          fiberPer100g: selected.fiberPer100g,
          proteinPer100g: selected.proteinPer100g,
          nutritionConfidence: selected.nutritionConfidence,
          effectiveAt: _date(selected.createdAt),
        ),
        historicalUnavailable: false,
      );
    }

    final current = _currentNutrition(ingredient);
    final changedAfterReference = history.any(
      (entry) => _date(entry.createdAt).isAfter(reference),
    );
    return _ResolvedNutrition(
      nutrition: current,
      historicalUnavailable:
          changedAfterReference &&
          _date(ingredient.updatedAt).isAfter(reference),
    );
  }

  IngredientNutritionData _currentNutrition(IngredientData ingredient) {
    return IngredientNutritionData(
      carbsPer100g: ingredient.carbsPer100g,
      fatPer100g: ingredient.fatPer100g,
      fiberPer100g: ingredient.fiberPer100g,
      proteinPer100g: ingredient.proteinPer100g,
      nutritionConfidence: ingredient.nutritionConfidence,
      effectiveAt: _date(ingredient.updatedAt),
    );
  }

  MealRecordData _mapMeal(MealData meal) {
    return MealRecordData(
      id: meal.id,
      name: meal.name,
      status: meal.status,
      plannedAt: _date(meal.plannedAt),
      summarizedAt: meal.summarizedAt == null
          ? null
          : _date(meal.summarizedAt!),
      mealTemplateId: meal.mealTemplateId,
      basedOnMealId: meal.basedOnMealId,
      notes: meal.notes,
      createdAt: _date(meal.createdAt),
      updatedAt: _date(meal.updatedAt),
      isSynced: meal.isSynced,
    );
  }

  MealAdvisorDecisionData _mapAdvisorDecision(MealAdvisorResultData decision) {
    return MealAdvisorDecisionData(
      result: decision.result,
      initialWaitTime: decision.initialWaitTime,
      finalWaitTime: decision.finalWaitTime,
      waitTimeIgnored: decision.waitTimeIgnored,
      decisionReason: decision.decisionReason,
      version: decision.version,
      isSynced: decision.isSynced,
      createdAt: _date(decision.createdAt),
      updatedAt: _date(decision.updatedAt),
    );
  }

  MealSnapshotDetailsData _mapSnapshot(MealSnapshotData snapshot) {
    return MealSnapshotDetailsData(
      id: snapshot.id,
      mealId: snapshot.mealId,
      snapshotType: snapshot.snapshotType,
      totalGrams: snapshot.totalGrams,
      totalCarbsG: snapshot.totalCarbsG,
      totalFiberG: snapshot.totalFiberG,
      totalNetCarbsG: snapshot.totalNetCarbsG,
      totalFatG: snapshot.totalFatG,
      totalProteinG: snapshot.totalProteinG,
      totalCaloriesKcal: snapshot.totalCaloriesKcal,
      ingredientsCount: snapshot.ingredientsCount,
      avgQuantityConfidence: snapshot.avgQuantityConfidence,
      minQuantityConfidence: snapshot.minQuantityConfidence,
      carbWeightedQuantityConfidence: snapshot.carbWeightedQuantityConfidence,
      wbtWeightedQuantityConfidence: snapshot.wbtWeightedQuantityConfidence,
      carbWeightedNutritionConfidence: snapshot.carbWeightedNutritionConfidence,
      wbtWeightedNutritionConfidence: snapshot.wbtWeightedNutritionConfidence,
      carbWeightedEffectiveConfidence: snapshot.carbWeightedEffectiveConfidence,
      wbtWeightedEffectiveConfidence: snapshot.wbtWeightedEffectiveConfidence,
      createdAt: _date(snapshot.createdAt),
      updatedAt: _date(snapshot.updatedAt),
      isSynced: snapshot.isSynced,
    );
  }

  MealStatusHistoryEntryData _mapStatusHistory(MealStatusHistoryData history) {
    return MealStatusHistoryEntryData(
      id: history.id,
      mealId: history.mealId,
      status: history.status,
      createdAt: _date(history.createdAt),
    );
  }

  DateTime _date(int millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _ResolvedNutrition {
  final IngredientNutritionData nutrition;
  final bool historicalUnavailable;

  const _ResolvedNutrition({
    required this.nutrition,
    required this.historicalUnavailable,
  });
}

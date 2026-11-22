import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/database_impl.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/dashboard/data/repositories/meal_advisor_result_store.dart';
import '../../../features/dashboard/data/use_cases/accept_meal_decision_use_case.dart';
import '../../../features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../meal/meal_decision.dart';

typedef AcceptedCaregiverMeal = ({MealAdvice advice, DateTime? bolusDueAt});

Future<AcceptedCaregiverMeal?> readAcceptedCaregiverMeal(
  DatabaseImpl db,
  String uid,
  int mealId,
) async {
  final meal = await db.mealDao.getMealById(mealId);
  if (meal?.status != 'planned') return null;
  final advice = await MealAdvisorResultUseCase(
    DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
  ).loadMealAdvice(mealId);
  final requestId = advice?.caregiverRequestId;
  if (advice?.source != 'caregiver' || requestId == null) return null;
  final receipt = await db
      .customSelect(
        'SELECT receipt.outcome_json FROM family_meal_decision_receipts receipt '
        'JOIN family_sync_identity identity ON identity.singleton=1 '
        'AND identity.owner_uid=receipt.owner_uid AND identity.source_id=receipt.source_id '
        'WHERE receipt.request_id=? AND receipt.owner_uid=? AND receipt.meal_id=?',
        variables: [Variable(requestId), Variable(uid), Variable(mealId)],
      )
      .getSingleOrNull();
  if (receipt == null) return null;
  final outcome = jsonDecode(receipt.read<String>('outcome_json'));
  if (outcome is! Map ||
      !outcome.containsKey('plannedAt') ||
      outcome['plannedAt'] != meal!.plannedAt) {
    return null;
  }
  final minutes = advice!.wait?.recommendedMinutes;
  final due =
      outcome['scheduled'] == true &&
          advice.decision == MealDecision.bolusWaitThenEat &&
          meal.plannedAt != null &&
          minutes != null
      ? DateTime.fromMillisecondsSinceEpoch(
          meal.plannedAt!,
        ).subtract(Duration(minutes: minutes))
      : null;
  return (advice: advice, bolusDueAt: due);
}

final startAcceptedCaregiverMealProvider = Provider(
  (ref) => (String uid, int mealId, {bool Function()? isCancelled}) async {
    final db = ref.read(databaseProvider);
    return db.transaction(() async {
      final accepted = await readAcceptedCaregiverMeal(db, uid, mealId);
      if (accepted == null ||
          accepted.bolusDueAt != null ||
          isCancelled?.call() == true) {
        return false;
      }
      await AcceptMealDecisionUseCase(ref).call(mealId, accepted.advice, alreadySaved: true);
      return true;
    });
  },
);

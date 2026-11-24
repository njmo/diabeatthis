import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/bolus_wizard.dart';
import '../../../core/domain/model/meal_status_flow.dart';
import '../../../core/drift/database_impl.dart' show DatabaseImpl;
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/dashboard/data/repositories/meal_advisor_result_store.dart';
import '../../../features/dashboard/data/use_cases/accept_meal_decision_use_case.dart';
import '../../../features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../meal/meal_bolus_coverage.dart';
import '../../meal/meal_decision.dart';
import '../../nutrition/stable_macro_ceil.dart';

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
      await AcceptMealDecisionUseCase(
        ref,
      ).call(mealId, accepted.advice, alreadySaved: true);
      return true;
    });
  },
);

/// An already accepted caregiver plan may start from a live calculator entry.
final startAcceptedMealFromCalculatorProvider = Provider(
  (ref) => (BolusWizard wizard) async {
    final now = clock.now();
    final dose = wizard.calculatorResult?.totalInsulin;
    if (!wizard.isValid ||
        dose == null ||
        !dose.isFinite ||
        dose < 0 ||
        !wizard.carbs.isFinite ||
        wizard.carbs <= 0 ||
        wizard.createdAt.isAfter(now) ||
        now.difference(wizard.createdAt) > const Duration(minutes: 5)) {
      return;
    }
    final db = ref.read(databaseProvider);
    if (!db.hasOpened) return;
    await db.transaction(() async {
      if (await mealBolusWizardAlreadyAssigned(db, wizard)) return;
      final identity = await db
          .customSelect(
            'SELECT owner_uid FROM family_sync_identity WHERE singleton=1 AND enabled=1',
          )
          .getSingleOrNull();
      final uid = identity?.readNullable<String>('owner_uid');
      if (uid == null) return;

      final candidates =
          await (db.select(db.meal)..where(
                (meal) =>
                    meal.purpose.equals('meal') &
                    meal.status.isIn([
                      'planned',
                      ...mealStatusesBlockingAnotherMealActivation,
                    ]),
              ))
              .get();
      if (candidates.any(
        (meal) => mealStatusBlocksAnotherMealActivation(meal.status),
      )) {
        return;
      }
      (int, MealAdvice)? match;
      for (final meal in candidates) {
        final accepted = await readAcceptedCaregiverMeal(db, uid, meal.id);
        if (accepted == null ||
            (accepted.advice.decision != MealDecision.bolusAndEatNow &&
                accepted.advice.decision != MealDecision.bolusWaitThenEat)) {
          continue;
        }
        if (wizard.createdAt.isBefore(accepted.advice.createdAt)) continue;
        final plannedAt = meal.plannedAt;
        if (accepted.bolusDueAt == null &&
            plannedAt != null &&
            DateTime.fromMillisecondsSinceEpoch(
                  plannedAt,
                ).difference(wizard.createdAt).abs() >
                const Duration(minutes: 20)) {
          continue;
        }
        final expectedAt = accepted.bolusDueAt ?? accepted.advice.createdAt;
        final window = accepted.bolusDueAt == null
            ? const Duration(minutes: 20)
            : const Duration(minutes: 5);
        if (wizard.createdAt.difference(expectedAt).abs() > window) continue;
        final macros = await db.ingredientDao.totalsForMeal(meal.id);
        if (macros == null ||
            (wizard.carbs - macros.netCarbsGrams.ceilMacro()).abs() > 0.001) {
          continue;
        }
        if (match != null) return;
        match = (meal.id, accepted.advice);
      }
      if (match case (final mealId, final advice)) {
        await AcceptMealDecisionUseCase(
          ref,
        ).call(mealId, advice, alreadySaved: true);
      }
    });
  },
);

import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/confirm_reviewed_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_review_timing.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final decisions = [
    MealDecision.bolusAndEatNow,
    MealDecision.bolusWaitThenEat,
    MealDecision.eatNowBolusLater,
  ];
  RetrospectiveMealTiming timing(MealDecision decision) =>
      RetrospectiveMealTiming(
        choice: ManualMealDecision(
          decision: decision,
          waitMinutes: decision == MealDecision.bolusWaitThenEat ? 15 : 0,
        ),
        eatingMinutes: 10,
        bolusAfterStartMinutes: 20,
      );
  for (final oldDecision in decisions) {
    for (final decision in decisions) {
      test(
        'confirmation replaces $oldDecision with $decision including timestamps',
        () async {
          final db = DatabaseImpl(NativeDatabase.memory());
          addTearDown(db.close);
          final start = DateTime(2026, 9, 10, 12);
          final id = await db
              .into(db.meal)
              .insert(
                MealCompanion.insert(
                  name: 'Meal',
                  plannedAt: start.millisecondsSinceEpoch,
                ),
              );
          final oldHistory = timing(
            oldDecision,
          ).history(start.subtract(const Duration(hours: 1)));
          for (final event in oldHistory.entries.where(
            (event) => event.key != 'summarized',
          )) {
            await db.mealDao.updateMealStatus(
              id,
              event.key,
              occurredAt: event.value,
            );
          }
          await db.mealDao.updateMealStatus(id, 'skipped');
          final skipped = await (db.select(
            db.mealStatusHistory,
          )..where((row) => row.status.equals('skipped'))).getSingle();
          await ConfirmReviewedMealUseCase(db, MealWizardLinkRepository(db))(
            wizard: domain.BolusWizard(
              nightscoutObjectId: 'id',
              remoteSource: 'https://example.com',
              createdAt: start,
              date: start,
              glucose: 120,
              units: null,
              notes: null,
              calculatorResult: null,
            ),
            mealId: id,
            relationType: MealWizardRelationType.initial,
            timing: MealReviewTiming(
              startedAt: start,
              timing: timing(decision),
            ),
          );
          final events = await db.select(db.mealStatusHistory).get();
          expect(
            manualMealDecisionFromHistory(events.map((s) => s.status)),
            decision,
          );
          final actual = {
            for (final event in events.where(
              (event) => event.status != 'skipped',
            ))
              event.status: event.createdAt,
          };
          final expected = {
            for (final event
                in timing(decision)
                    .history(start)
                    .entries
                    .where((event) => event.key != 'summarized'))
              event.key: event.value.millisecondsSinceEpoch,
          };
          expect(actual, expected);
          expect(
            events.singleWhere((event) => event.status == 'skipped'),
            skipped,
          );
          final meals = await DayLocalHistoryRepository(
            db,
          ).loadRecordedMeals(DateTime(2026, 9, 10), DateTime(2026, 9, 11));
          expect(meals.single.eatenAt, start);
        },
      );
    }
  }
  test(
    'failure during replay restores old history, meal status and assignment',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final start = DateTime(2026, 9, 10, 12);
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Rollback',
              plannedAt: start.millisecondsSinceEpoch,
            ),
          );
      await db.mealDao.updateMealStatus(
        id,
        'eating-then-bolus',
        occurredAt: start.subtract(const Duration(hours: 1)),
      );
      await db.mealDao.updateMealStatus(id, 'skipped');
      final before = await db.select(db.mealStatusHistory).get();
      await db.customStatement(
        "CREATE TRIGGER fail_review BEFORE UPDATE OF status ON meal WHEN NEW.status = 'eaten' BEGIN SELECT RAISE(ABORT, 'test persistence failure'); END",
      );
      final links = MealWizardLinkRepository(db);
      await expectLater(
        ConfirmReviewedMealUseCase(db, links)(
          wizard: domain.BolusWizard(
            nightscoutObjectId: 'id',
            remoteSource: 'https://example.com',
            createdAt: start,
            date: start,
            glucose: 120,
            units: null,
            notes: null,
            calculatorResult: null,
          ),
          mealId: id,
          relationType: MealWizardRelationType.initial,
          timing: MealReviewTiming(
            startedAt: start,
            timing: timing(MealDecision.bolusAndEatNow),
          ),
        ),
        throwsA(isA<Exception>()),
      );
      expect(await db.select(db.mealStatusHistory).get(), before);
      expect((await db.mealDao.getMealById(id))!.status, 'skipped');
      expect(await links.forMeal(id), isEmpty);
      expect(await db.select(db.mealAdvisorResult).get(), isEmpty);
    },
  );
}

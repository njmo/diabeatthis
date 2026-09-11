import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/meal_status_flow.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/confirm_reviewed_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_review_timing.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  final day = DateTime(2026, 9, 11);
  final time = day.add(const Duration(hours: 13, minutes: 3));
  domain.BolusWizard wizard(String id) => domain.BolusWizard(
    nightscoutObjectId: id,
    remoteSource: 'https://example.com',
    createdAt: time,
    date: time,
    glucose: 120,
    units: null,
    notes: null,
    calculatorResult: null,
  );
  Future<int> meal(String status, DateTime at) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: status,
          plannedAt: at.millisecondsSinceEpoch,
          status: Value(status),
        ),
      );
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'candidates include planned and skipped meals only within selected day',
    () async {
      await meal('eaten', day.subtract(const Duration(minutes: 1)));
      final planned = await meal('planned', day.add(const Duration(hours: 23)));
      final skipped = await meal('skipped', time);
      await meal('planned', DateTime(2026, 9, 12));
      final local = DayLocalHistoryRepository(db);
      expect((await local.loadMealCandidates(day)).map((m) => m.id), [
        skipped,
        planned,
      ]);
      expect((await local.loadMeals(day, DateTime(2026, 9, 12))).count, 0);
    },
  );

  for (final status in ['planned', 'skipped']) {
    test(
      'linking $status records eating at wizard time and leaves summary pending',
      () async {
        final id = await meal(status, day.add(const Duration(hours: 18)));
        final links = MealWizardLinkRepository(db);
        expect(
          await ConfirmReviewedMealUseCase(db, links)(
            wizard: wizard('one'),
            mealId: id,
            relationType: MealWizardRelationType.initial,
            timing: MealReviewTiming(
              startedAt: time,
              timing: const RetrospectiveMealTiming(eatingMinutes: 10),
            ),
          ),
          isTrue,
        );
        final saved = await (db.select(
          db.meal,
        )..where((m) => m.id.equals(id))).getSingle();
        expect(saved.status, 'eaten');
        expect(mealStatusReadyToSummarize(saved.status), isTrue);
        expect(saved.summarizedAt, isNull);
        final local = DayLocalHistoryRepository(db);
        expect(
          (await local.loadRecordedMeals(
            day,
            DateTime(2026, 9, 12),
          )).single.eatenAt,
          time,
        );
        expect((await local.loadMeals(day, DateTime(2026, 9, 12))).count, 1);
        expect(
          await ConfirmReviewedMealUseCase(db, links)(
            wizard: wizard('one'),
            mealId: id,
            relationType: MealWizardRelationType.initial,
            timing: MealReviewTiming(
              startedAt: time,
              timing: const RetrospectiveMealTiming(eatingMinutes: 10),
            ),
          ),
          isFalse,
        );
        await links.unlink((await links.forMeal(id)).single.id);
        expect((await db.select(db.meal).get()).single.status, 'eaten');
      },
    );
  }

  test('conflicting link does not change skipped meal status', () async {
    final first = await meal('eaten', time);
    final second = await meal('skipped', time);
    final links = MealWizardLinkRepository(db);
    await ConfirmReviewedMealUseCase(db, links)(
      wizard: wizard('same'),
      mealId: first,
      relationType: MealWizardRelationType.initial,
      timing: MealReviewTiming(
        startedAt: time,
        timing: const RetrospectiveMealTiming(eatingMinutes: 10),
      ),
    );
    await expectLater(
      ConfirmReviewedMealUseCase(db, links)(
        wizard: wizard('same'),
        mealId: second,
        relationType: MealWizardRelationType.initial,
        timing: MealReviewTiming(
          startedAt: time,
          timing: const RetrospectiveMealTiming(eatingMinutes: 10),
        ),
      ),
      throwsStateError,
    );
    expect(
      (await (db.select(
        db.meal,
      )..where((m) => m.id.equals(second))).getSingle()).status,
      'skipped',
    );
  });
  for (final decision in [
    MealDecision.bolusWaitThenEat,
    MealDecision.eatNowBolusLater,
  ]) {
    test(
      'confirmation preserves historical times for $decision without summarizing',
      () async {
        final id = await meal('planned', day);
        final timing = RetrospectiveMealTiming(
          choice: ManualMealDecision(
            decision: decision,
            waitMinutes: decision == MealDecision.bolusWaitThenEat ? 15 : 0,
          ),
          eatingMinutes: 10,
          bolusAfterStartMinutes: 20,
        );
        await ConfirmReviewedMealUseCase(db, MealWizardLinkRepository(db))(
          wizard: wizard('timing'),
          mealId: id,
          relationType: MealWizardRelationType.initial,
          timing: MealReviewTiming(startedAt: time, timing: timing),
        );
        final events = await (db.select(
          db.mealStatusHistory,
        )..where((row) => row.mealId.equals(id))).get();
        final byStatus = {
          for (final event in events) event.status: event.createdAt,
        };
        for (final expected in timing.history(time).entries) {
          if (expected.key == 'summarized') continue;
          expect(byStatus[expected.key], expected.value.millisecondsSinceEpoch);
        }
        expect(byStatus.containsKey('summarized'), isFalse);
        final advice = await db.select(db.mealAdvisorResult).getSingle();
        expect(advice.result, 'manual');
        expect(advice.finalWaitTime, timing.choice.waitMinutes);
      },
    );
  }

  test(
    'unstarted meal cannot be linked without confirming its timing',
    () async {
      final id = await meal('planned', day);
      final links = MealWizardLinkRepository(db);
      await expectLater(
        ConfirmReviewedMealUseCase(db, links)(
          wizard: wizard('missing'),
          mealId: id,
          relationType: MealWizardRelationType.initial,
        ),
        throwsArgumentError,
      );
      expect(await links.forMeal(id), isEmpty);
      expect((await db.select(db.meal).getSingle()).status, 'planned');
    },
  );
}

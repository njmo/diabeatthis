import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/add_meal_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_meal_transaction_test.dart' show transactionMealDraft;

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final decision in [
    MealDecision.eatNowBolusLater,
    MealDecision.bolusAndEatNow,
    MealDecision.bolusWaitThenEat,
  ]) {
    test(
      'historical $decision preserves actual timeline, source and consumed quantities',
      () async {
        final draft = transactionMealDraft();
        final timing = RetrospectiveMealTiming(
          choice: ManualMealDecision(
            decision: decision,
            waitMinutes: decision == MealDecision.bolusWaitThenEat ? 15 : 0,
          ),
          eatingMinutes: 20,
          bolusAfterStartMinutes: 25,
        );
        final saved = await container
            .read(addMealControllerProvider.notifier)
            .addMeal(draft, retrospective: timing);
        final row = (await db.select(db.meal).get()).single;
        expect(row.status, 'summarized');
        final expectedHistory = switch (decision) {
          MealDecision.eatNowBolusLater => {
            'eating-then-bolus': draft.plannedAt,
            'waiting-for-bolus': draft.plannedAt.add(
              const Duration(minutes: 20),
            ),
            'eaten-bolused': draft.plannedAt.add(const Duration(minutes: 25)),
            'summarized': draft.plannedAt.add(const Duration(minutes: 25)),
          },
          MealDecision.bolusAndEatNow => {
            'waiting-for-bolus': draft.plannedAt,
            'bolused-eating': draft.plannedAt,
            'eaten': draft.plannedAt.add(const Duration(minutes: 20)),
            'summarized': draft.plannedAt.add(const Duration(minutes: 20)),
          },
          MealDecision.bolusWaitThenEat => {
            'waiting-for-bolus': draft.plannedAt.subtract(
              const Duration(minutes: 15),
            ),
            'bolused-waiting': draft.plannedAt.subtract(
              const Duration(minutes: 15),
            ),
            'waited-eating': draft.plannedAt,
            'eaten': draft.plannedAt.add(const Duration(minutes: 20)),
            'summarized': draft.plannedAt.add(const Duration(minutes: 20)),
          },
          _ => throw StateError('Unsupported test case'),
        };
        final history = await db.select(db.mealStatusHistory).get();
        expect({
          for (final event in history)
            event.status: DateTime.fromMillisecondsSinceEpoch(event.createdAt),
        }, expectedHistory);
        expect(
          row.createdAt,
          expectedHistory.values.first.millisecondsSinceEpoch,
        );
        expect(
          row.updatedAt,
          expectedHistory.values.last.millisecondsSinceEpoch,
        );
        expect(
          row.summarizedAt,
          expectedHistory.values.last.millisecondsSinceEpoch,
        );
        final result = (await db.select(db.mealAdvisorResult).get()).single;
        expect(result.result, 'manual');
        final ingredients = await db.select(db.mealIngredients).get();
        for (final item in ingredients) {
          expect(item.consumedAmount, item.amount);
          expect(item.consumedConfidence, 1);
          expect(item.entryType, 'planned');
        }
        final snapshots = await db.select(db.mealSnapshot).get();
        expect(snapshots, hasLength(2));
        expect(snapshots[0].totalNetCarbsG, snapshots[1].totalNetCarbsG);
        expect(
          snapshots[0].carbWeightedEffectiveConfidence,
          snapshots[1].carbWeightedEffectiveConfidence,
        );
        final details = await container
            .read(loadMealDetailsUseCaseProvider)
            .call(saved.id);
        expect(details.advisorDecision!.isManual, isTrue);
        expect(details.analysisTime, draft.plannedAt);
        expect(
          details.recordedEatingEndedAt,
          draft.plannedAt.add(const Duration(minutes: 20)),
        );
        expect(await db.mealDao.getNearestMeal(), isNull);
      },
    );
  }

  test('requires an eating duration to replay the complete history', () async {
    await expectLater(
      container
          .read(addMealControllerProvider.notifier)
          .addMeal(
            transactionMealDraft(),
            retrospective: const RetrospectiveMealTiming(),
          ),
      throwsArgumentError,
    );
    expect(await db.select(db.meal).get(), isEmpty);
  });

  test(
    'a failed decision write rolls back ingredients, snapshots and meal',
    () async {
      await db.customStatement(
        "CREATE TRIGGER fail_decision BEFORE INSERT ON meal_advisor_result BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        container
            .read(addMealControllerProvider.notifier)
            .addMeal(
              transactionMealDraft(),
              retrospective: const RetrospectiveMealTiming(eatingMinutes: 20),
            ),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.meal).get(), isEmpty);
      expect(await db.select(db.mealIngredients).get(), isEmpty);
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
      expect(await db.select(db.ingredient).get(), isEmpty);
    },
  );

  test('rejects future completion and insulin before the end of eating', () {
    final start = DateTime(2026, 1, 1, 12);
    expect(
      () => const RetrospectiveMealTiming(
        eatingMinutes: 20,
      ).validate(start, start.add(const Duration(minutes: 10))),
      throwsArgumentError,
    );
    expect(
      () => const RetrospectiveMealTiming(
        choice: ManualMealDecision(decision: MealDecision.eatNowBolusLater),
        eatingMinutes: 20,
        bolusAfterStartMinutes: 10,
      ).validate(start, start.add(const Duration(hours: 1))),
      throwsArgumentError,
    );
  });
}

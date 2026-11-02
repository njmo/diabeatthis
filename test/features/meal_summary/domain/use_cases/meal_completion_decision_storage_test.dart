import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_decision.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import 'complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;

void main() {
  final start = DateTime(2026, 11, 2, 12);
  final end = start.add(const Duration(minutes: 15));
  final now = start.add(const Duration(hours: 2));
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
      ],
    );
    await seedCompletionMeal(db);
    await db.mealDao.updateMealStatus(1, 'bolused-eating', occurredAt: start);
    await db.customStatement(
      'UPDATE meal_ingredients SET consumed_amount=150 WHERE id=1',
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<MealCompletionResult> save(
    MealCarbsCorrectionChoice? correctionChoice, {
    double consumed = 50,
  }) => withClock(
    Clock.fixed(now),
    () => container
        .read(completeMealUseCaseProvider)
        .call(
          draft: completionDraft(
            status: 'bolused-eating',
            consumed: consumed,
            reported: 150,
          ).copyWith(correctionChoice: correctionChoice),
          choice: MealCompletionChoice.less,
          endedAt: end,
        ),
  );

  for (final choice in MealCarbsCorrectionChoice.values) {
    test(
      'persists explicit $choice with actual amounts and distinct decision/eating times',
      () async {
        await save(choice);
        final meal = (await db.mealDao.getMealById(1))!;
        final decision = MealCompletionDecision.decode(
          meal.completionDecision,
        )!;
        expect(meal.status, 'summarized');
        expect(decision.choice, choice);
        expect(decision.recordedAt, now);
        expect(decision.eatingEndedAt, end);
        // The original plan was 20 g; the reported portion with its add-on was 30 g.
        expect(decision.reportedCarbs, 30);
        expect(decision.consumedCarbs, 10);
        expect(decision.proposedCorrectionCarbs, -20);
        expect(
          (await db.select(db.mealSnapshot).get()).single.totalNetCarbsG,
          10,
        );
        expect(
          (await db.mealIngredientsDao.getMealIngredientsForMeal(
            1,
          )).single.consumedAmount,
          50,
        );
      },
    );
  }

  test('ordinary completion preserves an earlier explicit decision', () async {
    final previous = MealCompletionDecision(
      choice: MealCarbsCorrectionChoice.withoutCorrection,
      recordedAt: start,
      eatingEndedAt: start,
      reportedCarbs: 40,
      consumedCarbs: 30,
      proposedCorrectionCarbs: -10,
    ).encode();
    await db.customStatement(
      'UPDATE meal SET completion_decision=? WHERE id=1',
      [previous],
    );
    await save(null);
    final meal = (await db.mealDao.getMealById(1))!;
    expect(meal.status, 'summarized');
    expect(meal.completionDecision, previous);
  });

  test(
    'ordinary completion does not infer a correction choice from a shortfall',
    () async {
      await save(null);
      expect((await db.mealDao.getMealById(1))!.completionDecision, isNull);
    },
  );

  test(
    'stored correction uses the existing integer rounding without changing actual totals',
    () async {
      await save(MealCarbsCorrectionChoice.withoutCorrection, consumed: 51);
      final decision = MealCompletionDecision.decode(
        (await db.mealDao.getMealById(1))!.completionDecision,
      )!;
      expect(decision.consumedCarbs, closeTo(10.2, 0.000001));
      expect(decision.proposedCorrectionCarbs, -19);
    },
  );

  test(
    'a failed snapshot rolls back the decision, amounts and completion status together',
    () async {
      await db.customStatement('''CREATE TRIGGER fail_consumed_snapshot
      BEFORE INSERT ON meal_snapshot WHEN NEW.snapshot_type='consumed'
      BEGIN SELECT RAISE(ABORT, 'snapshot failure'); END''');
      await expectLater(
        save(MealCarbsCorrectionChoice.withoutCorrection),
        throwsA(isA<Exception>()),
      );
      final meal = (await db.mealDao.getMealById(1))!;
      expect(meal.status, 'bolused-eating');
      expect(meal.completionDecision, isNull);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        150,
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
    },
  );

  test(
    'optional decision metadata rejects malformed, unknown and invalid payloads',
    () {
      final valid =
          jsonDecode(
                MealCompletionDecision(
                  choice: MealCarbsCorrectionChoice.withoutCorrection,
                  recordedAt: now,
                  eatingEndedAt: end,
                  reportedCarbs: 30,
                  consumedCarbs: 10,
                  proposedCorrectionCarbs: -20,
                ).encode(),
              )
              as Map<String, dynamic>;
      for (final encoded in <String?>[
        null,
        '',
        'not-json',
        '[]',
        '{}',
        jsonEncode({...valid, 'version': 2}),
        jsonEncode({...valid, 'choice': 'unknown'}),
        jsonEncode({...valid, 'reportedCarbs': -1}),
        jsonEncode({...valid, 'consumedCarbs': '10'}),
        jsonEncode({...valid, 'proposedCorrectionCarbs': 20}),
        jsonEncode({...valid, 'recordedAt': 8640000000000001}),
      ]) {
        expect(MealCompletionDecision.decode(encoded), isNull);
      }
    },
  );
}

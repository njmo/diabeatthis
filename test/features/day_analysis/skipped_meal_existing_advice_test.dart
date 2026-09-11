import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/confirm_reviewed_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_review_timing.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final wait in [10, 20]) {
    test(
      'skipped meal with existing advice accepts actual wait of $wait minutes',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final start = DateTime(2026, 9, 10, 9, 37);
        final id = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Skipped breakfast',
                plannedAt: start.millisecondsSinceEpoch,
                status: const Value('skipped'),
              ),
            );
        await db
            .into(db.mealAdvisorResult)
            .insert(
              MealAdvisorResultCompanion.insert(
                mealId: Value(id),
                result: 'bolusWaitThenEat',
                initialWaitTime: 15,
                finalWaitTime: 15,
                waitTimeIgnored: false,
                extendedCarbsGrams: const Value(20),
                decisionReason: const Value('Original recommendation'),
              ),
            );
        final before = await db.select(db.mealAdvisorResult).getSingle();
        final links = MealWizardLinkRepository(db);
        final bolus = start.subtract(Duration(minutes: wait));
        await ConfirmReviewedMealUseCase(db, links)(
          wizard: domain.BolusWizard(
            nightscoutObjectId: 'remote',
            remoteSource: 'https://example.com',
            createdAt: bolus,
            date: bolus,
            glucose: 120,
            units: null,
            notes: null,
            calculatorResult: null,
          ),
          mealId: id,
          relationType: MealWizardRelationType.initial,
          timing: MealReviewTiming(
            startedAt: start,
            timing: RetrospectiveMealTiming(
              choice: ManualMealDecision(
                decision: MealDecision.bolusWaitThenEat,
                waitMinutes: wait,
              ),
              eatingMinutes: 15,
            ),
          ),
        );
        final saved = await db.select(db.mealAdvisorResult).getSingle();
        expect(saved.result, before.result);
        expect(saved.initialWaitTime, 15);
        expect(saved.finalWaitTime, wait);
        expect(saved.waitTimeIgnored, wait < 15);
        expect(saved.extendedCarbsGrams, before.extendedCarbsGrams);
        expect(saved.decisionReason, before.decisionReason);
        expect(saved.version, before.version);
        expect(saved.createdAt, before.createdAt);
        expect(await links.forMeal(id), hasLength(1));
        final meal = await db.select(db.meal).getSingle();
        expect(meal.status, 'eaten');
        expect(meal.summarizedAt, isNull);
        final events = await db.select(db.mealStatusHistory).get();
        expect(
          events
              .singleWhere((event) => event.status == 'waited-eating')
              .createdAt,
          start.millisecondsSinceEpoch,
        );
        expect(
          events.singleWhere((event) => event.status == 'eaten').createdAt,
          start.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
        );
      },
    );
  }
}

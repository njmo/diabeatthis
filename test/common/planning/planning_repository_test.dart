import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/common/planning/caregiver_meal_form_actions.dart';
import 'package:diabeatthis/common/planning/firebase_planning_repository.dart';
import 'package:diabeatthis/common/planning/planning_repository_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_entry_action.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/models/meal_ingredient_replacement_result.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../family_sync/family_meal_plan_form_test.dart'
    show FamilyPlanTestCatalog;

MealIngredientsDraft catalogEntry(String id, {bool reviewed = true}) =>
    MealIngredientsDraft(
      catalogId: id,
      catalogRevision: 'a' * 64,
      catalogReviewed: reviewed,
      ingredient: const IngredientDraft.draft(
        name: 'Identical product',
        carbsPer100g: 20,
        fatPer100g: 1,
        fiberPer100g: 2,
        proteinPer100g: 3,
        nutritionConfidence: .8,
        isReference: false,
      ),
      ingredientPortion: const IngredientPortionDraft(
        portion: PortionSelection.empty(),
        amount: 1,
      ),
      recordedGramsPerAmount: 1,
      amount: 100,
      quantityConfidence: 1,
      entryType: 'planned',
      consumedAmount: null,
      consumedConfidence: null,
    );
MealDraft plan(List<MealIngredientsDraft> items) => MealDraft(
  name: 'Lunch plan',
  category: MealCategory.lunch,
  mealIngredients: items,
  plannedAt: DateTime.now().add(const Duration(hours: 1)),
  status: 'planned',
);

void main() {
  late AppLocalizations language;
  setUp(() async {
    language = await AppLocalizations.delegate.load(const Locale('en'));
  });
  test('caregiver cannot fall back to a local planning repository', () async {
    final container = ProviderContainer(
      overrides: [
        applicationDeviceModeProvider.overrideWith(
          (_) async => ApplicationDeviceMode.caregiver,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(applicationDeviceModeProvider.future);
    expect(
      () => container.read(planningRepositoryProvider),
      throwsA(
        predicate(
          (error) => error.toString().contains('Caregiver planning requires'),
        ),
      ),
    );
  });
  test(
    'identical nutrition keeps distinct canonical catalog identities',
    () async {
      Map<String, dynamic>? sent;
      final repository = FirebasePlanningRepository(
        submit: (_, _, v) async {
          sent = v;
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final draft = container.read(mealDraftProvider.notifier);
      expect(draft.addMealIngredient(catalogEntry('one')), isTrue);
      expect(draft.addMealIngredient(catalogEntry('two')), isTrue);
      final result = await repository.saveMeal(
        plan(container.read(mealDraftProvider).mealIngredients),
        automaticName: false,
        language: language,
      );
      expect(result, isNull); // A pending cloud proposal is not a local Meal.
      expect((sent!['ingredients'] as List).map((i) => i['catalogId']), [
        'one',
        'two',
      ]);
    },
  );
  test(
    'duplicate replacement cannot mark the original catalog item reviewed',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = catalogEntry('one');
      final original = catalogEntry('two', reviewed: false);
      final notifier = container.read(mealDraftProvider.notifier)
        ..setMealIngredients([first, original]);
      expect(
        notifier.replaceMealIngredient(original, first),
        MealIngredientReplacementResult.duplicate,
      );
      final actions = CaregiverMealFormActions(
        rows: [],
        catalog: FamilyPlanTestCatalog(),
      );
      addTearDown(actions.dispose);
      final remaining = plan(container.read(mealDraftProvider).mealIngredients);
      expect(actions.canContinue(remaining), isFalse);
      var submitted = false;
      final repository = FirebasePlanningRepository(
        submit: (_, _, _) async {
          submitted = true;
        },
      );
      await expectLater(
        repository.saveMeal(
          remaining,
          automaticName: false,
          language: language,
        ),
        throwsStateError,
      );
      expect(submitted, isFalse);
      notifier.removeMealIngredient(original);
      expect(actions.canContinue(container.read(mealDraftProvider)), isTrue);
    },
  );
  test(
    'remote writes reject execution, invalid time, mass and duration before submission',
    () async {
      var calls = 0;
      final repository = FirebasePlanningRepository(
        submit: (_, _, _) async {
          calls++;
        },
      );
      final base = plan([catalogEntry('one')]);
      for (final invalid in [
        base.copyWith(status: 'eating'),
        base.copyWith(
          plannedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        base.copyWith(
          mealIngredients: [catalogEntry('one').copyWith(amount: 10001)],
        ),
        base.copyWith(
          mealIngredients: List.generate(31, (i) => catalogEntry('$i')),
        ),
      ]) {
        await expectLater(
          repository.saveMeal(
            invalid,
            automaticName: false,
            language: language,
          ),
          throwsA(isA<Error>()),
        );
      }
      for (final minutes in [null, 0, 1441]) {
        await expectLater(
          repository.saveActivity(
            DashboardActivityAction(
              activity: const ActivityDraft.existing(
                id: 1,
                name: 'Walk',
                percentagePre: 80,
                percentagePost: 80,
                durationMinutes: null,
              ),
              startedAt: base.plannedAt,
              isScheduled: true,
              durationMinutes: minutes,
            ),
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        repository.saveActivity(
          DashboardActivityAction(
            activity: const ActivityDraft.existing(
              id: 1,
              name: 'Walk',
              percentagePre: 80,
              percentagePost: 80,
              durationMinutes: 30,
            ),
            startedAt: base.plannedAt,
            isScheduled: false,
            durationMinutes: 30,
          ),
        ),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );
}

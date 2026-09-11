import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_meal_review_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/reconcile_day_meal_review_use_case.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  final date = DateTime(2026, 9, 10);
  final time = DateTime(2026, 9, 10, 13, 3);
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  domain.BolusWizard wizard(String id, DateTime at) => domain.BolusWizard(
    nightscoutObjectId: id,
    remoteSource: 'https://example.com',
    createdAt: at,
    date: at,
    glucose: 120,
    units: null,
    notes: null,
    calculatorResult: null,
  );

  Future<int> addMeal(DateTime at) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: 'Lunch',
          plannedAt: at.millisecondsSinceEpoch,
          status: const Value('summarized'),
        ),
      );

  ReconcileDayMealReviewUseCase review(List<domain.BolusWizard> wizards) {
    final links = MealWizardLinkRepository(db);
    final local = DayLocalHistoryRepository(db);
    final build = BuildDayMealReviewUseCase(
      loadTreatments: (_, _) async => wizards,
      loadAssignments: links.forWizards,
      loadMeals: (start, end, ids) =>
          local.loadRecordedMeals(start, end, includeIds: ids),
      now: () => date.add(const Duration(days: 1)),
    );
    return ReconcileDayMealReviewUseCase(
      build: build.call,
      linkAutomatically: (wizard, mealId) => links.link(
        mealId: mealId,
        remoteWizardId: wizard.nightscoutObjectId,
        remoteSource: wizard.remoteSource,
        automatic: true,
      ),
    );
  }

  test(
    'same minute is linked once; dismissal survives refresh and allows a later manual choice',
    () async {
      final meal = await addMeal(time);
      final run = review([
        wizard('one', time.add(const Duration(seconds: 40))),
      ]);
      final entries = await run(date);
      expect(entries, hasLength(1));
      expect(entries.single.meal!.id, meal);
      final links = MealWizardLinkRepository(db);
      final link = (await links.forMeal(meal)).single;
      await run(date);
      expect((await links.forMeal(meal)).single.id, link.id);
      await links.unlink(link.id);
      expect(
        (await run(date)).where((entry) => entry.meal == null),
        hasLength(1),
      );
      expect(await links.forMeal(meal), isEmpty);
      final other = await addMeal(time.add(const Duration(hours: 1)));
      await links.link(
        mealId: other,
        remoteWizardId: 'one',
        remoteSource: 'https://example.com',
      );
      expect(
        (await run(
          date,
        )).where((entry) => entry.meal?.id == other).single.wizards,
        hasLength(1),
      );
    },
  );

  test('ambiguous minutes and neighbouring minutes are not linked', () async {
    final id = await addMeal(time);
    final links = MealWizardLinkRepository(db);
    await review([
      wizard('one', time),
      wizard('two', time.add(const Duration(seconds: 20))),
    ])(date);
    expect(await links.forMeal(id), isEmpty);
    await review([wizard('three', time.add(const Duration(minutes: 1)))])(date);
    expect(await links.forMeal(id), isEmpty);
    await addMeal(time.add(const Duration(seconds: 1)));
    await review([wizard('four', time)])(date);
    expect(await db.select(db.mealWizardLink).get(), isEmpty);
  });
}

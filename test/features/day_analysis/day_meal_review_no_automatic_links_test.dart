import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_context_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  test(
    'day review never links same-minute entries and preserves explicit links on refresh',
    () async {
      final date = DateTime(2026, 9, 10);
      final time = date.add(const Duration(hours: 13));
      final wizard = domain.BolusWizard(
        nightscoutObjectId: 'wizard-1',
        remoteSource: 'https://example.com',
        createdAt: time.add(const Duration(seconds: 20)),
        date: time,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      final db = DatabaseImpl(NativeDatabase.memory());
      final build = BuildDayContextUseCase(
        now: () => date.add(const Duration(days: 1)),
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [wizard],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dayContextForDateProvider(
            date,
          ).overrideWith((ref) => build(date: date)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final mealId = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Lunch',
              plannedAt: time.millisecondsSinceEpoch,
              status: const Value('summarized'),
            ),
          );
      final subscription = container.listen(
        dayMealReviewProvider(date),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final links = MealWizardLinkRepository(db);
      for (var refresh = 0; refresh < 2; refresh++) {
        final entries = await container.read(
          dayMealReviewProvider(date).future,
        );
        expect(entries, hasLength(2));
        expect(
          entries.singleWhere((entry) => entry.meal == null).wizards.single,
          wizard,
        );
        expect(
          entries.singleWhere((entry) => entry.meal?.id == mealId).wizards,
          isEmpty,
        );
        expect(await db.select(db.mealWizardLink).get(), isEmpty);
        container.invalidate(dayMealReviewProvider(date));
      }
      await links.link(
        mealId: mealId,
        remoteWizardId: wizard.nightscoutObjectId,
        remoteSource: wizard.remoteSource,
      );
      container.invalidate(dayMealReviewProvider(date));
      final linked = await container.read(dayMealReviewProvider(date).future);
      expect(linked.single.meal?.id, mealId);
      expect(linked.single.wizards.single, wizard);
      final linkId = (await links.forMeal(mealId)).single.id;
      container.invalidate(dayMealReviewProvider(date));
      await container.read(dayMealReviewProvider(date).future);
      expect((await links.forMeal(mealId)).single.id, linkId);
    },
  );
}

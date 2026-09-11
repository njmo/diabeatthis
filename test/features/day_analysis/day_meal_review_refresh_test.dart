import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_context_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_meal_review_controller.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  test('link and unlink preserve already fetched day history', () async {
    final date = DateTime(2026, 1, 1);
    domain.BolusWizard wizard(DateTime time) => domain.BolusWizard(
      nightscoutObjectId: time.toString(),
      remoteSource: 'https://example.com',
      createdAt: time,
      date: time,
      glucose: 120,
      units: null,
      notes: null,
      calculatorResult: null,
    );
    var reads = 0;
    final build = BuildDayContextUseCase(
      now: () => date.add(const Duration(days: 1)),
      loadGlucose: (_, _) async => [],
      loadTreatments: (_, _) async {
        reads++;
        return [wizard(date.subtract(const Duration(hours: 1))), wizard(date)];
      },
      loadMeals: (_, _) async => emptyMeals,
      loadLowTreatments: (_, _) async => [],
      loadActivities: (_, _) async => [],
    );
    final db = DatabaseImpl(NativeDatabase.memory());
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
    final contextSubscription = container.listen(
      dayContextForDateProvider(date),
      (_, _) {},
    );
    final reviewSubscription = container.listen(
      dayMealReviewProvider(date),
      (_, _) {},
    );
    addTearDown(contextSubscription.close);
    addTearDown(reviewSubscription.close);
    final day = await container.read(dayContextForDateProvider(date).future);
    final review = await container.read(dayMealReviewProvider(date).future);
    expect(day.wizards, hasLength(1));
    expect(review.single.wizards.single.createdAt, date);
    expect(reads, 1);
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Recorded',
            plannedAt: date.millisecondsSinceEpoch,
            status: const Value('eaten'),
          ),
        );
    final controllerProvider = dayMealReviewControllerProvider(date);
    final controllerSubscription = container.listen(
      controllerProvider,
      (_, _) {},
    );
    addTearDown(controllerSubscription.close);
    await container.read(controllerProvider.future);
    final controller = container.read(controllerProvider.notifier);
    await controller.link(wizard(date), id, MealWizardRelationType.initial);
    await container.read(dayMealReviewProvider(date).future);
    expect(reads, 1);
    final link = (await MealWizardLinkRepository(db).forMeal(id)).single;
    await controller.unlink(link.id);
    await container.read(dayMealReviewProvider(date).future);
    expect(reads, 1);
  });
}

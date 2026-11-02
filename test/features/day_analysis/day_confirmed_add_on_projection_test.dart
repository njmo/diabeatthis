import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_review_entry.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_meal_review_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/reconcile_day_meal_review_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/meal_add_on_bolus_waiter.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;
import '../../foreground/utils/fake_notifications_controller.dart';
import '../../foreground/utils/fake_runtime_harness.dart';
import '../meal_summary/domain/use_cases/record_meal_add_on_use_case_test.dart'
    show addOnDraft, seedAddOnMeal;

void main() {
  test(
    'day rebuild keeps both confirmed add-on parts under the meal and leaves an undelivered calculator separate',
    () async {
      final date = DateTime(2026, 11, 2);
      final start = date.add(const Duration(hours: 12));
      final requestAt = start.add(const Duration(minutes: 10));
      final now = requestAt.add(const Duration(minutes: 25));
      final db = DatabaseImpl(NativeDatabase.memory());
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dataSourceConfigProvider.overrideWithValue(
            const AsyncData(
              DataSourceConfig(
                bgSource: BgSource.cloud,
                treatmentsSource: TreatmentsSource.aaps,
                pumpStatusSource: PumpStatusSource.cloud,
                historySource: HistorySource.local,
                mirrorToLocal: true,
              ),
            ),
          ),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(() async {
        harness.cancel();
        container.dispose();
        await db.close();
      });
      await seedAddOnMeal(db, start);
      final draft = await addOnDraft(db, meat: 500);
      await withClock(
        Clock.fixed(requestAt),
        () => container.read(recordMealAddOnUseCaseProvider).call(draft),
      );
      final zero = testBolusWizard(
        createdAt: requestAt.add(const Duration(minutes: 1)),
        carbs: 50,
        insulin: 0,
      );
      final first = testBolusWizard(
        createdAt: requestAt.add(const Duration(minutes: 23)),
        carbs: 48,
        insulin: 44.7,
      );
      final second = testBolusWizard(
        createdAt: requestAt.add(const Duration(minutes: 24)),
        carbs: 2,
        insulin: 1,
      );
      await LocalMirrorWriter(db.localMirrorDao).mirrorTreatments([
        zero,
        first,
        ManualBolus(
          externalId: 'first-delivery',
          createdAt: first.createdAt.add(const Duration(milliseconds: 2400)),
          insulin: 3,
        ),
        second,
        ManualBolus(
          externalId: 'second-delivery',
          createdAt: second.createdAt.add(const Duration(milliseconds: 2400)),
          insulin: 3,
        ),
      ], TreatmentsSource.aaps);

      Future<List<DayMealReviewEntry>> rebuildReview() {
        final local = DayLocalHistoryRepository(db);
        final links = MealWizardLinkRepository(db);
        final build = BuildDayMealReviewUseCase(
          loadTreatments: LocalTreatmentsHistoryRepository(
            db.localMirrorDao,
          ).fetchTreatmentsBetween,
          loadAssignments: links.forWizards,
          loadMeals: (start, end, ids) =>
              local.loadRecordedMeals(start, end, includeIds: ids),
          now: () => now,
        );
        return ReconcileDayMealReviewUseCase(
          build: build.call,
          linkAutomatically: (_, _) async => fail(
            'Later add-on submissions require workflow evidence, not minute matching',
          ),
        )(date);
      }

      final before = await rebuildReview();
      expect(before.where((entry) => entry.meal == null), hasLength(3));
      expect(
        before.singleWhere((entry) => entry.meal?.id == 1).wizards,
        isEmpty,
      );

      final confirmed = await withClock(
        Clock.fixed(now),
        () async => const MealAddOnBolusWaiter()(
          harness.runtimeContext,
          MealMonitorContext(
            activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
          ),
          remindImmediately: false,
        ),
      );
      expect(confirmed, isTrue);

      for (var reload = 0; reload < 2; reload++) {
        final review = await rebuildReview();
        expect(review, hasLength(2));
        final meal = review.singleWhere((entry) => entry.meal?.id == 1);
        expect(meal.wizards.map((wizard) => wizard.carbs), [48, 2]);
        expect(meal.assignments.map((assignment) => assignment.type), [
          MealWizardRelationType.initial,
          MealWizardRelationType.continuation,
        ]);
        for (final wizard in meal.wizards) {
          expect(wizard.localId, isNotNull);
          expect(
            meal.assignments.where((assignment) => assignment.matches(wizard)),
            hasLength(1),
          );
        }
        expect(
          review
              .singleWhere((entry) => entry.meal == null)
              .wizards
              .single
              .createdAt,
          zero.createdAt,
        );
      }
      expect(await db.mealWizardLinkDao.forMeal(1), hasLength(2));
    },
  );
}

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../meals/data/providers/meal_wizard_link_repository_provider.dart';
import '../../domain/models/day_meal_review_entry.dart';
import '../../domain/models/day_recorded_meal.dart';
import '../../domain/use_cases/build_day_meal_review_use_case.dart';
import '../../domain/use_cases/reconcile_day_meal_review_use_case.dart';
import '../repositories/day_local_history_repository.dart';
import 'day_context_provider.dart';

final dayMealReviewProvider = FutureProvider.autoDispose
    .family<List<DayMealReviewEntry>, DateTime>((ref, date) {
      final today = clock.now().toLocal();
      final isToday = date == DateTime(today.year, today.month, today.day);
      final context = ref.watch(
        (isToday ? dayContextProvider : dayContextForDateProvider(date)).future,
      );
      final local = DayLocalHistoryRepository(ref.watch(databaseProvider));
      final links = ref.watch(mealWizardLinkRepositoryProvider);
      final build = BuildDayMealReviewUseCase(
        loadTreatments: (_, _) async {
          final wizards = (await context).wizards;
          if (wizards == null) {
            throw StateError('Day treatment history unavailable');
          }
          return wizards;
        },
        loadAssignments: links.forWizards,
        loadMeals: (start, end, ids) =>
            local.loadRecordedMeals(start, end, includeIds: ids),
        now: clock.now,
      );
      return ReconcileDayMealReviewUseCase(
        build: build.call,
        linkAutomatically: (wizard, mealId) => links.link(
          mealId: mealId,
          localWizardId: wizard.localId,
          remoteWizardId: wizard.remoteSource == null
              ? null
              : wizard.nightscoutObjectId,
          remoteSource: wizard.nightscoutObjectId == null
              ? null
              : wizard.remoteSource,
          automatic: true,
        ),
      )(date);
    });

final dayMealCandidatesProvider = FutureProvider.autoDispose
    .family<List<DayRecordedMeal>, DateTime>((ref, date) {
      return DayLocalHistoryRepository(
        ref.watch(databaseProvider),
      ).loadMealCandidates(date);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/model/meal.dart';
import '../../core/drift/providers/database_provider.dart';
import '../../features/activity/data/drafts/activity_entry_action.dart';
import '../../features/activity/data/drafts/activity_log_draft.dart';
import '../../features/activity/data/providers/activity_provider.dart';
import '../../features/activity/data/services/activity_schedule_service.dart';
import '../../features/meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../features/meals/data/domain/use_cases/log_retrospective_meal_use_case.dart';
import '../../features/meals/data/domain/use_cases/save_meal_draft_use_case.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/data/models/retrospective_meal_timing.dart';
import '../app_mode/application_device_mode.dart';
import '../l10n/language.dart';
import 'planning_repository.dart';

/// Local transactions retain their existing durable mirror triggers.
class LocalPlanningRepository implements PlanningRepository {
  const LocalPlanningRepository(this.ref);
  final Ref ref;
  Future<void> checkMode() async {
    final mode = await ref.read(applicationDeviceModeProvider.future);
    if (mode != ApplicationDeviceMode.patient ||
        ref.read(applicationDeviceModeProvider).asData?.value !=
            ApplicationDeviceMode.patient) {
      throw StateError('Patient mode is required for local planning');
    }
  }

  @override
  Future<Meal?> insertMeal(
    MealDraft draft, {
    RetrospectiveMealTiming? retrospective,
  }) async {
    await checkMode();
    return retrospective == null
        ? ref.read(addMealUseCaseProvider).call(draft)
        : LogRetrospectiveMealUseCase(ref).call(draft, retrospective);
  }

  @override
  Future<Meal?> saveMeal(
    MealDraft draft, {
    required bool automaticName,
    required AppLocalizations language,
    RetrospectiveMealTiming? retrospective,
  }) async {
    await checkMode();
    return SaveMealDraftUseCase(ref).call(
      draft,
      automaticName: automaticName,
      language: language,
      retrospective: retrospective,
    );
  }

  @override
  Future<void> proposeMeal(Map<String, dynamic> values) =>
      throw StateError('Use a local meal draft');
  @override
  Future<void> moveActivity(int occurrenceId, DateTime start) async {
    await checkMode();
    return ref.read(activityScheduleServiceProvider).move(occurrenceId, start);
  }

  @override
  Future<int?> saveActivity(DashboardActivityAction action) async {
    await checkMode();
    if (action.isScheduled) {
      final db = ref.read(databaseProvider);
      await db.transaction(() async {
        final activity = await saveActivityDraft(db, action.activity);
        if (activity == null) throw StateError('Could not save activity');
        await ref
            .read(activityScheduleServiceProvider)
            .planOnce(
              activityId: activity.id,
              start: action.startedAt,
              durationMinutes: action.durationMinutes,
            );
      });
      return null;
    }
    final log = await ref.read(
      insertActivityLogProvider(
        ActivityLogDraft(
          activity: action.activity,
          startedAt: action.startedAt,
          endedAt: action.endedAt,
        ),
      ).future,
    );
    return log.id;
  }
}

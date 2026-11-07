import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/model/activity.dart';
import '../../core/drift/database_impl.dart' show ActivityScheduleData;
import '../../core/drift/mappers/activity_drift_mapper.dart';
import '../../core/drift/providers/database_provider.dart';
import '../../features/activity/data/drafts/activity_draft.dart';
import '../../features/activity/data/drafts/activity_schedule_draft.dart';
import '../../features/activity/data/mappers/activity_draft_mapper.dart';
import '../../features/activity/data/providers/activity_provider.dart';
import '../../features/activity/data/services/activity_schedule_service.dart';
import 'activity_schedule_activation_repository.dart';
import 'local_planning_repository.dart';

abstract interface class ActivityCatalogRepository {
  ActivityCatalogRepository beginEdit();
  Future<Activity?> saveDefinition(
    ActivityDraft draft, {
    ActivityScheduleDraft? schedule,
  });
  Future<void> addSchedule(
    Activity activity,
    ActivityScheduleDraft schedule,
    int? duration,
  );
}

final activityCatalogMaximumDurationProvider = Provider<int?>((ref) => null);

final activityCatalogRepositoryProvider = Provider<ActivityCatalogRepository>(
  (ref) => LocalActivityCatalogRepository(ref),
);

class LocalActivityCatalogRepository
    implements ActivityCatalogRepository, ActivityScheduleActivationRepository {
  const LocalActivityCatalogRepository(this.ref);
  final Ref ref;
  @override
  Future<void> setScheduleEnabled(
    ActivityScheduleData rule,
    bool enabled,
  ) async {
    await LocalPlanningRepository(ref).checkMode();
    await ref.read(activityScheduleServiceProvider).setEnabled(rule, enabled);
  }

  @override
  ActivityCatalogRepository beginEdit() => this;
  @override
  Future<Activity?> saveDefinition(
    ActivityDraft draft, {
    ActivityScheduleDraft? schedule,
  }) async {
    await LocalPlanningRepository(ref).checkMode();
    final db = ref.read(databaseProvider);
    return db.transaction(() async {
      final activity = await draft.map(
        draft: (_) => saveActivityDraft(db, draft),
        existing: (_) async => (await db.activityDao.updateActivity(
          draft.toDomain().toCompanion(),
        )).toDomain(),
      );
      if (activity == null) throw StateError('Could not save activity');
      if (schedule != null) {
        await addSchedule(activity, schedule, activity.durationMinutes);
      }
      return activity;
    });
  }

  @override
  Future<void> addSchedule(
    Activity activity,
    ActivityScheduleDraft schedule,
    int? duration,
  ) async {
    await LocalPlanningRepository(ref).checkMode();
    await ref
        .read(activityScheduleServiceProvider)
        .save(
          activityId: activity.id,
          weekdays: schedule.weekdays,
          startMinute: schedule.startMinute,
          durationMinutes: duration,
          mode: schedule.confirmationMode,
          previousDayMinute: schedule.previousDayMinute,
          validFrom: schedule.validFrom,
          validUntil: schedule.validUntil,
        );
  }
}

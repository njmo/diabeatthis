import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/activity.dart';
import '../../../../core/domain/model/activity_log.dart';
import '../../../../core/drift/mappers/activity_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';

part 'activity_provider.g.dart';

@riverpod
class ActivityDraftNotifier extends _$ActivityDraftNotifier {
  @override
  Activity build() {
    return Activity.draft();
  }

  void setName(String value) => state = state.copyWith(name: value);
  String? getName() => state.name;

  void overrideDraft(Activity activity) => state = activity;
}

@riverpod
Future<List<Activity>> activitiesByQuery(Ref ref, String query) async {
  final db = ref.watch(databaseProvider);
  final act = await db.activityDao.searchActivitiesByName(query, 6).get();
  return act.map((e) => e.toDomain()).toList();
}

@riverpod
Future<Activity?> insertActivity(Ref ref, Activity activity) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.insertActivity(activity.toCompanion());
  if (value == null) return null;
  return value.toDomain();
}

@riverpod
Future<ActivityLog> insertActivityLog(Ref ref, ActivityLog activityLog) async {
  final db = ref.watch(databaseProvider);
  return await db.activityDao
      .insertActivityLog(activityLog.toCompanion())
      .then((value) => value.toDomain());
}

@riverpod
Future<void> stopActivity(Ref ref, ActivityLog activityLog) async {
  final db = ref.watch(databaseProvider);
  final updated = activityLog.map(
    existing: (a) => a.copyWith(endedAt: DateTime.now()),
    view: (a) => a.copyWith(endedAt: DateTime.now()),
    draft: (a) => throw StateError('Nie można zakończyć draftu – brak id i endedAt'),
  );
  await db.activityDao.updateActivityLog(updated.toCompanion());
}

@riverpod
Future<ActivityLog?> getPendingActivity(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.getActiveActivityLog();
  print(value);
  if (value == null) return null;

  final activity = await db.activityDao.getActivityById(value.activityId);
  return ActivityLog.view(
    id: value.id,
    activityName: activity.name,
    startedAt: DateTime.fromMillisecondsSinceEpoch(value.startedAt),
    endedAt: value.endedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value.endedAt!),
    activityId: activity.id,
  );
}

@riverpod
Future<Activity?> getActivityById(Ref ref, int id) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.getActivityById(id);
  return value.toDomain();
}

enum ActivityDialogStep { add, search, confirm }

@riverpod
class ActivityDialogController extends _$ActivityDialogController {
  @override
  ActivityDialogStep build() {
    return ActivityDialogStep.search;
  }

  void addState() => state = ActivityDialogStep.add;
  void searchState() => state = ActivityDialogStep.search;
  void confirmState() => state = ActivityDialogStep.confirm;
  void toOppositeState() {
    switch (state) {
      case ActivityDialogStep.add:
        state = ActivityDialogStep.search;
        break;
      case ActivityDialogStep.search:
        state = ActivityDialogStep.add;
        break;
      case ActivityDialogStep.confirm:
        state = ActivityDialogStep.search;
        break;
    }
  }
}

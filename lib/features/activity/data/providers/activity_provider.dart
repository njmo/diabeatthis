import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/activity.dart';
import '../../../../core/domain/model/activity_log.dart';
import '../../../../core/drift/mappers/activity_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';

part 'activity_provider.g.dart';

@riverpod
class ActivityDraftNotifier extends _$ActivityDraftNotifier {
  @override
  Activity build() {
    return Activity.empty();
  }

  void setName(String value) {
    state = state.map(
      existing: (a) => a.copyWith(name: value),
      draft: (a) => a.copyWith(name: value),
      empty: (_) =>
          Activity.draft(name: value, percentagePre: 0, percentagePost: 0),
    );
  }

  void setPercentagePre(String value) {
    state = state.map(
      existing: (a) => a.copyWith(percentagePre: int.tryParse(value) ?? 0),
      draft: (a) => a.copyWith(percentagePre: int.tryParse(value) ?? 0),
      empty: (_) => Activity.draft(
        name: '',
        percentagePre: int.tryParse(value) ?? 0,
        percentagePost: 0,
      ),
    );
  }

  void setPercentagePost(String value) {
    state = state.map(
      existing: (a) => a.copyWith(percentagePost: int.tryParse(value) ?? 0),
      draft: (a) => a.copyWith(percentagePost: int.tryParse(value) ?? 0),
      empty: (_) => Activity.draft(
        name: '',
        percentagePre: 0,
        percentagePost: int.tryParse(value) ?? 0,
      ),
    );
  }

  String? getName() => state.map(
    existing: (a) => a.name,
    draft: (a) => a.name,
    empty: (_) => '',
  );

  int? getPercentagePre() => state.map(
    existing: (a) => a.percentagePre,
    draft: (a) => a.percentagePre,
    empty: (_) => 0,
  );

  int? getPercentagePost() => state.map(
    existing: (a) => a.percentagePost,
    draft: (a) => a.percentagePost,
    empty: (_) => 0,
  );

  void overrideDraft(Activity activity) => state = activity;
}

@riverpod
class ActivityControllerNotifier extends _$ActivityControllerNotifier {
  @override
  void build() {
    return;
  }

  Future<Activity?> saveActivity(Activity act, [DateTime? date]) async {
    final db = ref.watch(databaseProvider);
    final isDraft = act.maybeWhen(
      draft: (_, __, ___) => true,
      orElse: () => false,
    );
    if (isDraft) {
      final value = await db.activityDao.insertActivity(act.toCompanion());
      if (value == null) return null;
      return value.toDomain();
    } else {
      return act;
    }
  }
}

@riverpod
Future<List<Activity>> activitiesByQuery(Ref ref, String query) async {
  final db = ref.watch(databaseProvider);
  final act = await db.activityDao.searchActivitiesByName(query, 6).get();
  return act.map((e) => e.toDomain()).toList();
}

@riverpod
Future<List<Activity>> activitiyLogByQuery(Ref ref, String query) async {
  final db = ref.watch(databaseProvider);
  final act = await db.activityDao.searchActivitiesByName(query, 6).get();
  return act.map((e) => e.toDomain()).toList();
}

@riverpod
Future<ActivityLog> insertActivityLog(Ref ref, ActivityLog activityLog) async {
  final db = ref.watch(databaseProvider);
  return await db.activityDao
      .insertActivityLog(activityLog.toCompanion())
      .then((value) => value.toDomain());
}

@riverpod
Future<List<ActivityLog>> getActivityLogs(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.getActivityLogs();
  final activityLogs = <ActivityLog>[];
  for (final log in value) {
    final activity = await db.activityDao.getActivityById(log.activityId);
    activityLogs.add(ActivityLog.view(
      id: log.id,
      activityName: activity.name,
      startedAt: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
      endedAt: log.endedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(log.endedAt!),
      activityId: activity.id,
    ));
  }
  return activityLogs;
}

@riverpod
Future<void> stopActivity(Ref ref, ActivityLog activityLog) async {
  final db = ref.watch(databaseProvider);
  final updated = activityLog.map(
    existing: (a) => a.copyWith(endedAt: clock.now()),
    view: (a) => a.copyWith(endedAt: clock.now()),
    draft: (a) =>
        throw StateError('Nie można zakończyć draftu – brak id i endedAt'),
  );
  if(activityLog.startedAt.isBefore(clock.now())) {
    await db.activityDao.updateActivityLog(updated.toCompanion());
  } else {
    await db.activityDao.removeActivityLog(updated.toCompanion());
  }
}

@riverpod
Future<ActivityLog?> getPendingActivity(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.getActiveActivityLog();
  Log.i('getPendingActivityProvider', 'value: $value');

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

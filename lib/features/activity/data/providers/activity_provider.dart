import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/activity.dart' as domain;
import '../../../../core/domain/model/activity_log.dart' as domain;
import '../../../../core/drift/database_impl.dart' as db;
import '../../../../core/drift/mappers/activity_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';

part 'activity_provider.g.dart';

const activityLogListPageSize = 10;
const activityListPageSize = 10;

@riverpod
class ActivityDraftNotifier extends _$ActivityDraftNotifier {
  @override
  domain.Activity build() {
    return domain.Activity.empty();
  }

  void setName(String value) {
    state = state.map(
      existing: (a) => a.copyWith(name: value),
      draft: (a) => a.copyWith(name: value),
      empty: (_) => domain.Activity.draft(
        name: value,
        percentagePre: 0,
        percentagePost: 0,
        durationMinutes: null,
      ),
    );
  }

  void setPercentagePre(String value) {
    state = state.map(
      existing: (a) => a.copyWith(percentagePre: int.tryParse(value) ?? 0),
      draft: (a) => a.copyWith(percentagePre: int.tryParse(value) ?? 0),
      empty: (_) => domain.Activity.draft(
        name: '',
        percentagePre: int.tryParse(value) ?? 0,
        percentagePost: 0,
        durationMinutes: null,
      ),
    );
  }

  void setPercentagePost(String value) {
    state = state.map(
      existing: (a) => a.copyWith(percentagePost: int.tryParse(value) ?? 0),
      draft: (a) => a.copyWith(percentagePost: int.tryParse(value) ?? 0),
      empty: (_) => domain.Activity.draft(
        name: '',
        percentagePre: 0,
        percentagePost: int.tryParse(value) ?? 0,
        durationMinutes: null,
      ),
    );
  }

  void setDurationMinutes(String value) {
    final trimmedValue = value.trim();
    final duration = trimmedValue.isEmpty ? null : int.tryParse(trimmedValue);
    state = state.map(
      existing: (a) => a.copyWith(durationMinutes: duration),
      draft: (a) => a.copyWith(durationMinutes: duration),
      empty: (_) => domain.Activity.draft(
        name: '',
        percentagePre: 0,
        percentagePost: 0,
        durationMinutes: duration,
      ),
    );
  }

  void setHasPlannedDuration(bool value) {
    state = state.map(
      existing: (a) => a.copyWith(
        durationMinutes: value
            ? a.durationMinutes ?? domain.defaultPlannedActivityDurationMinutes
            : null,
      ),
      draft: (a) => a.copyWith(
        durationMinutes: value
            ? a.durationMinutes ?? domain.defaultPlannedActivityDurationMinutes
            : null,
      ),
      empty: (_) => domain.Activity.draft(
        name: '',
        percentagePre: 0,
        percentagePost: 0,
        durationMinutes: value
            ? domain.defaultPlannedActivityDurationMinutes
            : null,
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

  int? getDurationMinutes() => state.map(
    existing: (a) => a.durationMinutes,
    draft: (a) => a.durationMinutes,
    empty: (_) => null,
  );

  bool hasPlannedDuration() => state.map(
    existing: (a) => a.durationMinutes != null,
    draft: (a) => a.durationMinutes != null,
    empty: (_) => false,
  );

  void reset() => state = domain.Activity.empty();

  void overrideDraft(domain.Activity activity) => state = activity;
}

@riverpod
class ActivityControllerNotifier extends _$ActivityControllerNotifier {
  @override
  void build() {
    return;
  }

  Future<domain.Activity?> saveActivity(
    domain.Activity act, [
    DateTime? date,
  ]) async {
    final db = ref.watch(databaseProvider);
    final isDraft = act.maybeMap(draft: (_) => true, orElse: () => false);
    if (isDraft) {
      final value = await db.activityDao.insertActivity(act.toCompanion());
      if (value == null) return null;
      return value.toDomain();
    } else {
      return act;
    }
  }

  Future<domain.Activity> updateActivity(domain.Activity activity) async {
    final db = ref.watch(databaseProvider);
    final value = await db.activityDao.updateActivity(activity.toCompanion());
    return value.toDomain();
  }
}

@riverpod
Future<List<domain.Activity>> activitiesByQuery(Ref ref, String query) async {
  final db = ref.watch(databaseProvider);
  final act = await db.activityDao.searchActivitiesByName(query, 6).get();
  return act.map((e) => e.toDomain()).toList();
}

@riverpod
Future<List<domain.Activity>> activitiyLogByQuery(Ref ref, String query) async {
  final db = ref.watch(databaseProvider);
  final act = await db.activityDao.searchActivitiesByName(query, 6).get();
  return act.map((e) => e.toDomain()).toList();
}

@riverpod
Future<domain.ActivityLog> insertActivityLog(
  Ref ref,
  domain.ActivityLog activityLog,
) async {
  final db = ref.watch(databaseProvider);
  return await db.activityDao
      .insertActivityLog(activityLog.toCompanion())
      .then((value) => value.toDomain());
}

@riverpod
Stream<List<domain.Activity>> activityListStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.activityDao.watchActivities().map((value) => value.toDomainList());
}

@riverpod
Stream<List<domain.ActivityLog>> activityLogListStream(
  Ref ref, {
  required int? activityId,
}) {
  final db = ref.watch(databaseProvider);
  return db.activityDao
      .watchActivityLogViews(activityId: activityId)
      .map(
        (rows) => rows.map((row) {
          final log = row.readTable(db.activityLog);
          final activity = row.readTable(db.activity);
          return _activityLogView(log: log, activity: activity);
        }).toList(),
      );
}

@riverpod
Future<void> stopActivity(Ref ref, domain.ActivityLog activityLog) async {
  final db = ref.watch(databaseProvider);
  final updated = activityLog.map(
    existing: (a) => a.copyWith(endedAt: clock.now()),
    view: (a) => a.copyWith(endedAt: clock.now()),
    draft: (a) =>
        throw StateError('Nie można zakończyć draftu – brak id i endedAt'),
  );
  if (activityLog.startedAt.isBefore(clock.now())) {
    await db.activityDao.updateActivityLog(updated.toCompanion());
  } else {
    await db.activityDao.removeActivityLog(updated.toCompanion());
  }
}

@riverpod
Future<domain.ActivityLog?> getPendingActivity(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.getActiveActivityLogOrNull();
  Log.i('getPendingActivityProvider', 'value: $value');
  if (value == null) return null;

  final activity = await db.activityDao.getActivityById(value.activityId);
  return domain.ActivityLog.view(
    id: value.id,
    activityName: activity.name,
    startedAt: DateTime.fromMillisecondsSinceEpoch(value.startedAt),
    endedAt: value.endedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value.endedAt!),
    activityId: activity.id,
    durationMinutes: activity.durationMinutes,
  );
}

@riverpod
Future<domain.Activity?> getActivityById(Ref ref, int id) async {
  final db = ref.watch(databaseProvider);
  final value = await db.activityDao.getActivityById(id);
  return value.toDomain();
}

@riverpod
Stream<domain.Activity?> activityByIdStream(Ref ref, int id) {
  final db = ref.watch(databaseProvider);
  return db.activityDao.watchActivityById(id).map((value) => value?.toDomain());
}

enum ActivityPickerStep { initial, add, search }

@riverpod
class ActivityDialogController extends _$ActivityDialogController {
  @override
  ActivityPickerStep build() {
    return ActivityPickerStep.initial;
  }

  void initialState() => state = ActivityPickerStep.initial;
  void addState() => state = ActivityPickerStep.add;
  void searchState() => state = ActivityPickerStep.search;
  void toOppositeState() {
    switch (state) {
      case ActivityPickerStep.initial:
        state = ActivityPickerStep.search;
        break;
      case ActivityPickerStep.add:
        state = ActivityPickerStep.search;
        break;
      case ActivityPickerStep.search:
        state = ActivityPickerStep.add;
        break;
    }
  }
}

domain.ActivityLog _activityLogView({
  required db.ActivityLogData log,
  required db.ActivityData activity,
}) {
  return domain.ActivityLog.view(
    id: log.id,
    activityName: activity.name,
    startedAt: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
    endedAt: log.endedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(log.endedAt!),
    activityId: activity.id,
    durationMinutes: activity.durationMinutes,
  );
}

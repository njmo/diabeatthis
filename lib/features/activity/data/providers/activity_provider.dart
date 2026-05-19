import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/activity.dart' as domain;
import '../../../../core/domain/model/activity_log.dart' as domain;
import '../../../../core/drift/database_impl.dart' as db;
import '../../../../core/drift/mappers/activity_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../drafts/activity_draft.dart';
import '../drafts/activity_log_draft.dart';
import '../mappers/activity_draft_mapper.dart';
import '../mappers/activity_log_draft_mapper.dart';
import '../models/activity_log_summary_data.dart';

part 'activity_provider.g.dart';

const activityLogListPageSize = 10;
const activityListPageSize = 10;

@riverpod
class ActivityDraftNotifier extends _$ActivityDraftNotifier {
  @override
  ActivityDraft? build() => null;

  void setName(String value) {
    state =
        state?.map(
          existing: (a) => a.copyWith(name: value),
          draft: (a) => a.copyWith(name: value),
        ) ??
        ActivityDraft.draft(
          name: value,
          percentagePre: 0,
          percentagePost: 0,
          durationMinutes: null,
        );
  }

  void setPercentagePre(String value) {
    state =
        state?.map(
          existing: (a) => a.copyWith(percentagePre: int.tryParse(value) ?? 0),
          draft: (a) => a.copyWith(percentagePre: int.tryParse(value) ?? 0),
        ) ??
        ActivityDraft.draft(
          name: '',
          percentagePre: int.tryParse(value) ?? 0,
          percentagePost: 0,
          durationMinutes: null,
        );
  }

  void setPercentagePost(String value) {
    state =
        state?.map(
          existing: (a) => a.copyWith(percentagePost: int.tryParse(value) ?? 0),
          draft: (a) => a.copyWith(percentagePost: int.tryParse(value) ?? 0),
        ) ??
        ActivityDraft.draft(
          name: '',
          percentagePre: 0,
          percentagePost: int.tryParse(value) ?? 0,
          durationMinutes: null,
        );
  }

  void setDurationMinutes(String value) {
    final trimmedValue = value.trim();
    final duration = trimmedValue.isEmpty ? null : int.tryParse(trimmedValue);
    state =
        state?.map(
          existing: (a) => a.copyWith(durationMinutes: duration),
          draft: (a) => a.copyWith(durationMinutes: duration),
        ) ??
        ActivityDraft.draft(
          name: '',
          percentagePre: 0,
          percentagePost: 0,
          durationMinutes: duration,
        );
  }

  void setHasPlannedDuration(bool value) {
    state =
        state?.map(
          existing: (a) => a.copyWith(
            durationMinutes: value
                ? a.durationMinutes ??
                      domain.defaultPlannedActivityDurationMinutes
                : null,
          ),
          draft: (a) => a.copyWith(
            durationMinutes: value
                ? a.durationMinutes ??
                      domain.defaultPlannedActivityDurationMinutes
                : null,
          ),
        ) ??
        ActivityDraft.draft(
          name: '',
          percentagePre: 0,
          percentagePost: 0,
          durationMinutes: value
              ? domain.defaultPlannedActivityDurationMinutes
              : null,
        );
  }

  String? getName() =>
      state?.map(existing: (a) => a.name, draft: (a) => a.name) ?? '';

  int? getPercentagePre() =>
      state?.map(
        existing: (a) => a.percentagePre,
        draft: (a) => a.percentagePre,
      ) ??
      0;

  int? getPercentagePost() =>
      state?.map(
        existing: (a) => a.percentagePost,
        draft: (a) => a.percentagePost,
      ) ??
      0;

  int? getDurationMinutes() => state?.map(
    existing: (a) => a.durationMinutes,
    draft: (a) => a.durationMinutes,
  );

  bool hasPlannedDuration() =>
      state?.map(
        existing: (a) => a.durationMinutes != null,
        draft: (a) => a.durationMinutes != null,
      ) ??
      false;

  void reset() => state = null;

  void overrideDraft(ActivityDraft activity) => state = activity;
}

@riverpod
class ActivityControllerNotifier extends _$ActivityControllerNotifier {
  @override
  void build() {
    return;
  }

  Future<domain.Activity> updateActivity(ActivityDraft activity) async {
    final db = ref.watch(databaseProvider);
    final value = await db.activityDao.updateActivity(
      activity.toDomain().toCompanion(),
    );
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
  ActivityLogDraft activityLog,
) async {
  final db = ref.watch(databaseProvider);
  return db.transaction(() async {
    final activity = await _saveActivityDraft(db, activityLog.activity);
    if (activity == null) {
      throw Exception('Could not insert activity');
    }
    return await db.activityDao
        .insertActivityLog(activityLog.toCompanion(activityId: activity.id))
        .then((value) => value.toDomain());
  });
}

@riverpod
Stream<List<domain.Activity>> activityListStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.activityDao.watchActivities().map((value) => value.toDomainList());
}

@riverpod
Stream<List<ActivityLogSummaryData>> activityLogListStream(
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
Future<void> stopActivity(Ref ref, ActivityLogSummaryData activityLog) async {
  final db = ref.watch(databaseProvider);
  final updated = domain.ActivityLog(
    id: activityLog.id,
    activityId: activityLog.activityId,
    startedAt: activityLog.startedAt,
    endedAt: clock.now(),
  );
  if (activityLog.startedAt.isBefore(clock.now())) {
    await db.activityDao.updateActivityLog(updated.toCompanion());
  } else {
    await db.activityDao.removeActivityLog(updated.toCompanion());
  }
}

@riverpod
Stream<ActivityLogSummaryData?> getPendingActivity(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.activityDao.watchActiveActivityLogView().map((rows) {
    if (rows.isEmpty) {
      Log.i('getPendingActivityProvider', 'value: null');
      return null;
    }

    final row = rows.first;
    final log = row.readTable(db.activityLog);
    final activity = row.readTable(db.activity);
    Log.i('getPendingActivityProvider', 'value: $log');
    return _activityLogView(log: log, activity: activity);
  });
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

ActivityLogSummaryData _activityLogView({
  required db.ActivityLogData log,
  required db.ActivityData activity,
}) {
  return ActivityLogSummaryData(
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

Future<domain.Activity?> _saveActivityDraft(
  db.DatabaseImpl db,
  ActivityDraft activity,
) {
  return activity.map(
    draft: (draft) async {
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw ArgumentError('Activity name cannot be empty');
      }
      final value = await db.activityDao.insertActivity(
        draft.copyWith(name: name).toCompanion(),
      );
      return value?.toDomain();
    },
    existing: (_) async => activity.toDomain(),
  );
}

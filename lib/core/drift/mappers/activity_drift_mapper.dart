import 'package:drift/drift.dart' as d;

import '../../domain/model/activity.dart';
import '../../domain/model/activity_log.dart';
import '../entity/activity.dart';

extension ActivityLogDataToDomain on ActivityLogData {
  ActivityLog toDomain() => ActivityLog(
    id: id,
    activityId: activityId,
    startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
    endedAt: (endedAt == null)
        ? null
        : DateTime.fromMillisecondsSinceEpoch(endedAt!),
  );
}

extension ActivityDataToDomain on ActivityData {
  Activity toDomain() => Activity(
    id: id,
    name: name,
    percentagePre: percentagePre,
    percentagePost: percentagePost,
    durationMinutes: durationMinutes,
  );
}

extension ActivityDataIterableToDomain on Iterable<ActivityData> {
  List<Activity> toDomainList() => map((e) => e.toDomain()).toList();
}

extension ActivityLogDataIterableToDomain on Iterable<ActivityLogData> {
  List<ActivityLog> toDomainList() => map((e) => e.toDomain()).toList();
}

extension ActivityLogToCompanion on ActivityLog {
  ActivityLogCompanion toCompanion() {
    return ActivityLogCompanion(
      id: d.Value(id),
      activityId: d.Value(activityId),
      startedAt: d.Value(startedAt.millisecondsSinceEpoch),
      endedAt: d.Value(endedAt?.millisecondsSinceEpoch),
    );
  }
}

extension ActivityToCompanion on Activity {
  ActivityCompanion toCompanion() {
    return ActivityCompanion(
      id: d.Value(id),
      name: d.Value(name),
      percentagePre: d.Value(percentagePre),
      percentagePost: d.Value(percentagePost),
      durationMinutes: d.Value(durationMinutes),
    );
  }
}

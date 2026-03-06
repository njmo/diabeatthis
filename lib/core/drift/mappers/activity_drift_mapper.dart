import 'package:drift/drift.dart' as d;

import '../../domain/model/activity.dart';
import '../../domain/model/activity_log.dart';
import '../entity/activity.dart';

extension ActivityLogDataToDomain on ActivityLogData {
  ActivityLog toDomain() => ActivityLog.existing(
    id: id,
    activityId: activityId,
    startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
    endedAt: (endedAt == null)
        ? null
        : DateTime.fromMillisecondsSinceEpoch(endedAt!),
  );
}

extension ActivityDataToDomain on ActivityData {
  Activity toDomain() => Activity.existing(
    id: id,
    name: name,
    percentagePre: percentagePre,
    percentagePost: percentagePost,
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
    return map(
      draft: (e) => ActivityLogCompanion(
        id: d.Value<int>.absent(),
        activityId: d.Value(e.activityId),
        startedAt: d.Value(e.startedAt.millisecondsSinceEpoch),
      ),
      existing: (e) => ActivityLogCompanion(
        id: d.Value(e.id),
        activityId: d.Value(e.activityId),
        startedAt: d.Value(e.startedAt.millisecondsSinceEpoch),
        endedAt: d.Value(e.endedAt!.millisecondsSinceEpoch),
      ),
      view: (e) => throw StateError("View should not be pushed"),
    );
  }
}

extension ActivityToCompanion on Activity {
  ActivityCompanion toCompanion() {
    return map(
      draft: (e) => ActivityCompanion(
        id: d.Value<int>.absent(),
        name: d.Value(e.name),
        percentagePre: d.Value(e.percentagePre),
        percentagePost: d.Value(e.percentagePost),
      ),
      existing: (e) => ActivityCompanion(
        id: d.Value(e.id),
        name: d.Value(e.name),
        percentagePre: d.Value(e.percentagePre),
        percentagePost: d.Value(e.percentagePost),
      ),
      empty: (_) => throw StateError("Empty should not be pushed"),
    );
  }
}

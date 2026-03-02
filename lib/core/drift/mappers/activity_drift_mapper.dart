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
  Activity toDomain() => Activity.existing(id: id, name: name);
}

extension ActivityDataIterableToDomain on Iterable<ActivityData> {
  List<Activity> toDomainList() => map((e) => e.toDomain()).toList();
}

extension ActivityLogDataIterableToDomain on Iterable<ActivityLogData> {
  List<ActivityLog> toDomainList() => map((e) => e.toDomain()).toList();
}

extension ActivityLogToCompanion on ActivityLog {
  ActivityLogCompanion toCompanion() {
    final id = map(
      draft: (_) => d.Value<int>.absent(),
      existing: (e) => d.Value(e.id),
      view: (e) => d.Value(e.id),
    );
    return ActivityLogCompanion(
      id: id,
      activityId: d.Value(activityId),
      startedAt: d.Value(startedAt.millisecondsSinceEpoch),
      endedAt: map(
        draft: (_) => d.Value<int>.absent(),
        existing: (e) => d.Value(e.endedAt!.millisecondsSinceEpoch),
        view: (e) => d.Value(e.endedAt!.millisecondsSinceEpoch)
      ),
    );
  }
}

extension ActivityToCompanion on Activity {
  ActivityCompanion toCompanion() {
    final id = map(
      draft: (_) => d.Value<int>.absent(),
      existing: (e) => d.Value(e.id),
    );
    return ActivityCompanion(id: id, name: d.Value(name!));
  }
}

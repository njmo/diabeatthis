import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/providers/database_provider.dart';
import '../../models/activity_log_details_data.dart';

part 'load_activity_log_details_use_case.g.dart';

@Riverpod(keepAlive: true)
LoadActivityLogDetailsUseCase loadActivityLogDetailsUseCase(Ref ref) {
  return LoadActivityLogDetailsUseCase(ref: ref);
}

class LoadActivityLogDetailsUseCase {
  final Ref ref;

  const LoadActivityLogDetailsUseCase({required this.ref});

  Future<ActivityLogDetailsData> call(int activityLogId) async {
    final db = ref.read(databaseProvider);
    final log = await db.activityDao.getActivityLogById(activityLogId);
    final activity = await db.activityDao.getActivityById(log.activityId);

    return ActivityLogDetailsData(
      id: log.id,
      activityId: activity.id,
      activityName: activity.name,
      percentagePre: activity.percentagePre,
      percentagePost: activity.percentagePost,
      startedAt: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
      endedAt: log.endedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(log.endedAt!),
      intensity: log.intensity,
      notes: log.notes,
      isSynced: log.isSynced,
      createdAt: DateTime.fromMillisecondsSinceEpoch(log.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(log.updatedAt),
    );
  }
}

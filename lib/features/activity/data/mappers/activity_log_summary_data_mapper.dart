import '../../../../core/drift/dao/activity_dao.dart';
import '../models/activity_log_summary_data.dart';

extension ActivityLogViewDataMapper on ActivityLogViewData {
  ActivityLogSummaryData toSummaryData() {
    return ActivityLogSummaryData(
      id: log.id,
      activityName: activity.name,
      activityId: activity.id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
      endedAt: log.endedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(log.endedAt!),
      durationMinutes: activity.durationMinutes,
    );
  }
}

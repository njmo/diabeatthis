import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../activity/data/mappers/activity_log_summary_data_mapper.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';

part 'low_treatment_related_activity_provider.g.dart';

const lowTreatmentRelatedActivityWindow = Duration(hours: 1);

@riverpod
Future<ActivityLogSummaryData?> lowTreatmentRelatedActivityCandidate(
  Ref ref,
) async {
  final db = ref.watch(databaseProvider);
  final row = await db.activityDao.getActiveActivityLogView();
  final pendingActivity = row?.toSummaryData();
  final now = clock.now();

  if (pendingActivity == null) {
    return null;
  }

  if (!isLowTreatmentRelatedActivityCandidate(pendingActivity, now)) {
    return null;
  }

  return pendingActivity;
}

bool isLowTreatmentRelatedActivityCandidate(
  ActivityLogSummaryData activityLog,
  DateTime now,
) {
  if (activityLog.startedAt.isAfter(now)) {
    return false;
  }

  if (activityLog.endedAt != null) {
    return false;
  }

  final durationMinutes = activityLog.durationMinutes;
  if (durationMinutes != null) {
    final plannedEnd = activityLog.startedAt.add(
      Duration(minutes: durationMinutes),
    );
    return !plannedEnd.isBefore(now);
  }

  return !activityLog.startedAt.isBefore(
    now.subtract(lowTreatmentRelatedActivityWindow),
  );
}

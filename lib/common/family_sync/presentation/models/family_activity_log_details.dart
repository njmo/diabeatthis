import '../../../../features/activity/data/models/activity_log_details_data.dart';
import '../../../../features/activity/presentation/models/activity_log_page_state.dart';

ActivityLogPageState? familyActivityLogDetails(
  List<Map<String, dynamic>> rows,
  int id,
) {
  final p =
      rows
              .where(
                (r) =>
                    r['kind'] == 'activityLogs' &&
                    r['deleted'] != true &&
                    r['id'] == '$id',
              )
              .firstOrNull?['payload']
          as Map?;
  if (p == null) return null;
  final activity =
      rows
              .where(
                (r) =>
                    r['kind'] == 'activities' &&
                    r['deleted'] != true &&
                    r['id'] == '${p['activity_id']}',
              )
              .firstOrNull?['payload']
          as Map?;
  DateTime date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
  return ActivityLogPageState(
    data: ActivityLogDetailsData(
      id: id,
      activityId: p['activity_id'] as int,
      activityName: activity?['name'] as String? ?? '—',
      // Not projected for historic sessions; corresponding sections are omitted.
      percentagePre: 0,
      percentagePost: 0,
      durationMinutes: null,
      startedAt: date(p['started_at']),
      endedAt: p['ended_at'] == null ? null : date(p['ended_at']),
      intensity: p['intensity'] as String?,
      notes: p['notes'] as String?,
      summarizedAt: p['summarized_at'] == null
          ? null
          : date(p['summarized_at']),
      isSynced: true,
      createdAt: date(p['created_at']),
      updatedAt: date(p['updated_at']),
    ),
  );
}

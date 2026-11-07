import '../../../../features/activity/data/models/activity_log_summary_data.dart';
import '../models/collection_state.dart';
import 'activity_logs_controller.dart';

class CaregiverActivityLogsController implements ActivityLogsController {
  CaregiverActivityLogsController({
    required List<Map<String, dynamic>> rows,
    required this.open,
    required this.onRetry,
    bool loading = false,
    bool failed = false,
    int? activityId,
  }) : state = CollectionState(
         items:
             rows
                 .where(
                   (r) => r['kind'] == 'activityLogs' && r['deleted'] != true,
                 )
                 .where(
                   (r) =>
                       ((r['payload'] as Map)['started_at'] as int) <=
                       DateTime.now().millisecondsSinceEpoch,
                 )
                 .where(
                   (r) =>
                       activityId == null ||
                       (r['payload'] as Map)['activity_id'] == activityId,
                 )
                 .map((r) {
                   final p = r['payload'] as Map;
                   final activity =
                       rows
                               .where(
                                 (a) =>
                                     a['kind'] == 'activities' &&
                                     a['deleted'] != true &&
                                     a['id'] == '${p['activity_id']}',
                               )
                               .firstOrNull?['payload']
                           as Map?;
                   return ActivityLogSummaryData(
                     id: p['id'] as int,
                     activityId: p['activity_id'] as int,
                     activityName: activity?['name'] as String? ?? '—',
                     startedAt: DateTime.fromMillisecondsSinceEpoch(
                       p['started_at'] as int,
                     ),
                     endedAt: p['ended_at'] == null
                         ? null
                         : DateTime.fromMillisecondsSinceEpoch(
                             p['ended_at'] as int,
                           ),
                     durationMinutes: activity?['duration_minutes'] as int?,
                     intensity: p['intensity'] as String?,
                     notes: p['notes'] as String?,
                   );
                 })
                 .toList()
               ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
         loading: loading,
         failed: failed,
       );
  @override
  final CollectionState<ActivityLogSummaryData> state;
  @override
  final void Function(ActivityLogSummaryData)? open;
  @override
  Future<bool> Function(ActivityLogSummaryData)? get delete => null;
  final void Function() onRetry;
  @override
  void retry() => onRetry();
  @override
  void loadMore() {}
}

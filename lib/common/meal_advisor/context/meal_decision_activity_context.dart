import '../../planning/is_upcoming_activity_occurrence.dart';

class MealDecisionActivityContext {
  const MealDecisionActivityContext({
    required this.kind,
    required this.id,
    required this.name,
    required this.at,
    required this.planned,
    this.endedAt,
  });
  final String kind, name;
  final int id;
  final DateTime at;
  final DateTime? endedAt;
  final bool planned;

  static List<MealDecisionActivityContext> fromRows(
    List<Map<String, dynamic>> rows,
    DateTime asOf,
  ) {
    final live = rows.where((r) => r['deleted'] != true).toList();
    String? name(int id) =>
        (live
                    .where((r) => r['kind'] == 'activities' && r['id'] == '$id')
                    .firstOrNull?['payload']
                as Map?)?['name']
            as String?;
    final entries = <MealDecisionActivityContext>[];
    for (final row in live) {
      if (row['payload'] is! Map) continue;
      final p = row['payload'] as Map;
      if (row['kind'] == 'activityLogs' &&
          p['id'] is int &&
          p['activity_id'] is int &&
          p['started_at'] is int) {
        final start = DateTime.fromMillisecondsSinceEpoch(
          p['started_at'] as int,
        );
        final end = p['ended_at'] is int
            ? DateTime.fromMillisecondsSinceEpoch(p['ended_at'] as int)
            : null;
        final activityName = name(p['activity_id'] as int);
        if (activityName != null &&
            !start.isAfter(asOf) &&
            (end == null ||
                (!end.isAfter(asOf) &&
                    !end.isBefore(asOf.subtract(const Duration(hours: 3)))))) {
          entries.add(
            MealDecisionActivityContext(
              endedAt: end,
              kind: 'activityLogs',
              id: p['id'] as int,
              name: activityName,
              at: start,
              planned: false,
            ),
          );
        }
      }
      if (row['kind'] == 'activityOccurrences' &&
          p['activity_id'] is int &&
          p['started_at'] is int &&
          p['status'] is String) {
        final start = DateTime.fromMillisecondsSinceEpoch(
          p['started_at'] as int,
        );
        final activityName = name(p['activity_id'] as int);
        final log =
            live
                    .where(
                      (r) =>
                          r['kind'] == 'activityLogs' &&
                          r['id'] == '${p['activity_log_id']}',
                    )
                    .firstOrNull?['payload']
                as Map?;
        final logStarted =
            log?['started_at'] is int &&
            (log!['started_at'] as int) <= asOf.millisecondsSinceEpoch;
        if (activityName != null &&
            !start.isBefore(asOf) &&
            !const {
              'skipped',
              'cancelled',
              'missed',
              'completed',
            }.contains(p['status']) &&
            !logStarted &&
            log?['ended_at'] == null &&
            isUpcomingActivityOccurrence(
              status: p['status'] as String,
              startedAt: p['started_at'] as int,
              now: asOf,
            ) &&
            !start.isAfter(asOf.add(const Duration(hours: 2)))) {
          entries.add(
            MealDecisionActivityContext(
              kind: 'activities',
              id: p['activity_id'] as int,
              name: activityName,
              at: start,
              planned: true,
            ),
          );
        }
      }
    }
    return entries..sort((a, b) => a.at.compareTo(b.at));
  }
}

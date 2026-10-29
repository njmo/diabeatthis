import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../drafts/activity_entry_action.dart';
import '../drafts/activity_log_draft.dart';
import '../providers/activity_provider.dart';
import 'activity_schedule_service.dart';

Future<int?> saveActivityAction(
  WidgetRef ref,
  DashboardActivityAction action,
) async {
  if (action.isScheduled) {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      final activity = await saveActivityDraft(db, action.activity);
      if (activity == null) throw StateError('Could not save activity');
      await ref
          .read(activityScheduleServiceProvider)
          .planOnce(
            activityId: activity.id,
            start: action.startedAt,
            durationMinutes: action.durationMinutes,
          );
    });
  } else {
    final log = await ref.read(
      insertActivityLogProvider(
        ActivityLogDraft(
          activity: action.activity,
          startedAt: action.startedAt,
          endedAt: action.endedAt,
        ),
      ).future,
    );
    return log.id;
  }
  return null;
}

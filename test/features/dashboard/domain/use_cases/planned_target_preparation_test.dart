import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/save_started_activity_use_case.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_log_draft.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/build_dashboard_status_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 9, 30);
  ActivityLogSummaryData plan(DateTime start) => ActivityLogSummaryData(id: 1, activityId: 1,
    activityName: 'WF', startedAt: start, endedAt: null, durationMinutes: 45);

  test('an early target prepares the planned activity without starting it now', () {
    final planned = plan(now.add(const Duration(minutes: 60)));
    final target = TemporaryTarget(nightscoutId: 'preparation', createdAt: now.subtract(const Duration(minutes: 20)),
      durationInMiliseconds: 5400000, duration: 90, targetBottom: 140, targetTop: 140);
    final status = const BuildDashboardStatusUseCase()(now: now, pendingActivity: planned, target: target);
    expect(status.activity, planned);
    expect(status.activity!.startedAt, now.add(const Duration(minutes: 60)));
    expect(status.linkedTarget, target);
    expect(status.canAttachActivity, isFalse);
  });

  test('a distant plan does not block a deliberately started current session', () async {
    final planned = plan(now.add(const Duration(days: 1)));
    ActivityLogDraft? saved;
    final save = SaveStartedActivityUseCase(now: () => now, pendingActivity: () async => planned,
      save: (draft) async { saved = draft; });
    final draft = ActivityLogDraft(activity: const ActivityDraft.existing(id: 1, name: 'WF',
      percentagePre: 80, percentagePost: 100, durationMinutes: 45), startedAt: now);
    await save(draft);
    expect(saved, draft);
    expect(planned.startedAt, now.add(const Duration(days: 1)));
  });
}

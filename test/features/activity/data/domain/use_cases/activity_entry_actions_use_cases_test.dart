import 'package:diabeatthis/features/activity/data/domain/use_cases/end_activity_entry_use_case.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/save_started_activity_use_case.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_log_draft.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 9, 30);
  const definition = ActivityDraft.existing(id: 1, name: 'WF', percentagePre: 80, percentagePost: 100, durationMinutes: 45);
  ActivityLogSummaryData entry(DateTime start) => ActivityLogSummaryData(id: 1, activityId: 1,
    activityName: 'WF', startedAt: start, endedAt: null, durationMinutes: 45);

  test('a delayed selection preserves an earlier time today but prevents duplicates and future starts', () async {
    ActivityLogSummaryData? pending;
    final saved = <ActivityLogDraft>[];
    final save = SaveStartedActivityUseCase(now: () => now, pendingActivity: () async => pending,
      save: (draft) async { saved.add(draft); });
    final draft = ActivityLogDraft(activity: definition, startedAt: now.subtract(const Duration(minutes: 10)));
    await save(draft);
    expect(saved.single.startedAt, draft.startedAt);
    pending = entry(draft.startedAt);
    await expectLater(save(draft), throwsStateError);
    pending = null;
    await expectLater(save(draft.copyWith(startedAt: now.add(const Duration(minutes: 1)))), throwsArgumentError);
    await expectLater(save(draft.copyWith(startedAt: now.subtract(const Duration(days: 1)))), throwsArgumentError);
    expect(saved, hasLength(1));
  });

  test('ending a started entry and cancelling a planned entry use distinct guarded writes', () async {
    final finished = <int>[];
    final cancelled = <int>[];
    var unchanged = true;
    final end = EndActivityEntryUseCase(now: () => now,
      finishIfOpen: (id, start, end) async { expect(end, now); finished.add(id); return unchanged; },
      cancelIfUnchanged: (id, start) async { cancelled.add(id); return unchanged; });
    await end(entry(now.subtract(const Duration(minutes: 10))));
    await end(entry(now.add(const Duration(minutes: 10))));
    expect(finished, [1]);
    expect(cancelled, [1]);
    unchanged = false;
    await expectLater(end(entry(now.subtract(const Duration(minutes: 10)))), throwsStateError);
  });
}

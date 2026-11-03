import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/activity_log.dart';
import 'package:diabeatthis/features/activity/common/controllers/activity_actions_controller.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_log_draft.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the shared controller prevents a second write while saving an activity', () async {
    final now = DateTime(2026, 11, 3, 9, 30);
    final write = Completer<void>();
    var saves = 0;
    final container = ProviderContainer(overrides: [
      getPendingActivityProvider.overrideWithValue(const AsyncData(null)),
      insertActivityLogProvider.overrideWith((ref, draft) async {
        saves++;
        await write.future;
        return ActivityLog(id: 1, activityId: 1, startedAt: draft.startedAt, endedAt: null);
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(activityActionsControllerProvider, (_, _) {});
    await withClock(Clock.fixed(now), () async {
      final controller = container.read(activityActionsControllerProvider.notifier);
      final draft = ActivityLogDraft(activity: const ActivityDraft.existing(id: 1, name: 'WF',
        percentagePre: 80, percentagePost: 100, durationMinutes: 45), startedAt: now);
      final first = controller.saveStarted(draft);
      await expectLater(controller.saveStarted(draft), throwsStateError);
      write.complete();
      await first;
      expect(saves, 1);
      expect(container.read(activityActionsControllerProvider).isLoading, isFalse);
    });
  });
}

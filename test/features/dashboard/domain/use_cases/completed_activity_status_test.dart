import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/build_dashboard_status_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 3, 10);
  final end = start.add(const Duration(minutes: 30));
  final target = TemporaryTarget(
    nightscoutId: 'activity',
    createdAt: start,
    durationInMiliseconds: 3600000,
    duration: 60,
    targetBottom: 140,
    targetTop: 140,
  );
  ActivityLogSummaryData session({bool summarized = false}) =>
      ActivityLogSummaryData(
        id: 1,
        activityId: 1,
        activityName: 'Running',
        startedAt: start,
        endedAt: end,
        durationMinutes: 30,
        summarizedAt: summarized ? end : null,
        intensity: summarized ? 'moderate' : null,
        notes: summarized ? 'Good' : null,
      );
  const build = BuildDashboardStatusUseCase();

  test(
    'completed training retains the running target before and after summary',
    () {
      for (final summarized in [false, true]) {
        final entry = session(summarized: summarized);
        final result = build(
          now: end,
          pendingActivity: null,
          target: target,
          completedActivities: [entry],
        );
        expect(result.completedActivities, [entry]);
        expect(result.linkedCompletedActivityId, entry.id);
        expect(result.linkedTarget, target);
        expect(result.standaloneTarget, isNull);
      }
    },
  );

  test(
    'target expiry leaves the completed training available to summarize or close',
    () {
      final entry = session();
      final result = build(
        now: start.add(const Duration(hours: 1)),
        pendingActivity: null,
        target: target,
        completedActivities: [entry],
      );
      expect(result.completedActivities, [entry]);
      expect(result.linkedTarget, isNull);
      expect(result.linkedCompletedActivityId, isNull);
      expect(result.standaloneTarget, isNull);
    },
  );

  test(
    'later activity and meal targets never attach to a finished training',
    () {
      for (final unrelated in [
        target.copyWith(createdAt: end.add(const Duration(minutes: 1))),
        target.copyWith(targetBottom: 90, targetTop: 90),
      ]) {
        final result = build(
          now: end.add(const Duration(minutes: 2)),
          pendingActivity: null,
          target: unrelated,
          completedActivities: [session()],
        );
        expect(result.linkedCompletedActivityId, isNull);
        expect(result.standaloneTarget, unrelated);
      }
    },
  );

  test('target ending first does not hide the still active training', () {
    final ongoing = ActivityLogSummaryData(
      id: 2,
      activityId: 1,
      activityName: 'Running',
      startedAt: start,
      endedAt: null,
      durationMinutes: null,
    );
    final result = build(
      now: start.add(const Duration(hours: 2)),
      pendingActivity: ongoing,
      target: target,
    );
    expect(result.activity, ongoing);
    expect(result.linkedTarget, isNull);
  });
}

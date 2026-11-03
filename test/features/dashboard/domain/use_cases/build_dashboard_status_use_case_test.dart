import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/dashboard/common/models/status_timeline.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/build_dashboard_status_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 9, 30);
  const build = BuildDashboardStatusUseCase();
  ActivityLogSummaryData activity(DateTime start, {int? duration = 45}) => ActivityLogSummaryData(
    id: 1, activityId: 1, activityName: 'WF', startedAt: start, endedAt: null, durationMinutes: duration,
  );
  TemporaryTarget target(int value) => TemporaryTarget(nightscoutId: 'target', createdAt: now,
    durationInMiliseconds: 3600000, duration: 60, targetBottom: value, targetTop: value);

  test('meal targets stay independent from activities and activity targets link only to visible sessions', () {
    final session = activity(now);
    final meal = build(now: now, pendingActivity: session, target: target(90));
    expect(meal.activity, session);
    expect(meal.linkedTarget, isNull);
    expect(meal.standaloneTarget?.targetTop, 90);
    final linked = build(now: now, pendingActivity: session, target: target(140));
    expect(linked.linkedTarget?.targetTop, 140);
    expect(linked.standaloneTarget, isNull);
    final hidden = build(now: now, pendingActivity: activity(now.add(const Duration(days: 1))), target: target(140));
    expect(hidden.activity, isNull);
    expect(hidden.standaloneTarget?.targetTop, 140);
    expect(hidden.canAttachActivity, isTrue);
  });

  test('planned preparation becomes visible exactly 90 minutes before start', () {
    expect(build(now: now, pendingActivity: activity(now.add(const Duration(minutes: 91))), target: null).activity, isNull);
    expect(build(now: now, pendingActivity: activity(now.add(const Duration(minutes: 90))), target: null).activity, isNotNull);
    expect(build(now: now, pendingActivity: null, target: target(140)).canAttachActivity, isTrue);
  });

  test('an expired target is absent exactly at its end and manual activities have no progress', () {
    final expired = target(140).copyWith(createdAt: now.subtract(const Duration(hours: 1)));
    expect(build(now: now, pendingActivity: null, target: expired).standaloneTarget, isNull);
    final manual = activity(now.subtract(const Duration(hours: 3)), duration: null);
    expect(build(now: now, pendingActivity: manual, target: null).activity, manual);
    expect(StatusTimeline(start: manual.startedAt, now: now).progress, isNull);
    expect(StatusTimeline(start: now.subtract(const Duration(minutes: 45)), end: now, now: now).progress, 1);
    expect(StatusTimeline(start: now.subtract(const Duration(minutes: 45)), end: now, now: now).remainingMinutes, 0);
  });
}

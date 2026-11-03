import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_log_draft.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/attach_activity_to_target_use_case.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/attach_meal_to_target_use_case.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/load_meal_target_candidates_use_case.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/stop_dashboard_target_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 9, 30);
  final target = TemporaryTarget(nightscoutId: 'target', createdAt: now.subtract(const Duration(minutes: 70)),
    durationInMiliseconds: 10800000, duration: 180, targetBottom: 140, targetTop: 140);
  final mealTarget = target.copyWith(targetBottom: 90, targetTop: 90);
  final draft = ActivityLogDraft(activity: const ActivityDraft.existing(id: 1, name: 'WF',
    percentagePre: 80, percentagePost: 100, durationMinutes: 45), startedAt: now);

  test('activity attachment keeps its own selected start and rejects replaced or expired targets', () async {
    TemporaryTarget? current = target;
    var time = now;
    final saved = <ActivityLogDraft>[];
    final attach = AttachActivityToTargetUseCase(now: () => time, currentTarget: () => current,
      saveStartedActivity: (value) async { saved.add(value); });
    await attach(target, draft);
    expect(saved.single.startedAt, now);
    current = target.copyWith(nightscoutId: 'replacement');
    await expectLater(attach(target, draft), throwsStateError);
    current = target;
    time = target.createdAt.add(const Duration(minutes: 180));
    await expectLater(attach(target, draft), throwsStateError);
    expect(saved, hasLength(1));
  });

  test('meal attachment rejects a deleted meal and never writes a changed target link', () async {
    Meal? meal = const Meal(id: 1, name: 'Breakfast');
    TemporaryTarget? current = mealTarget;
    final saved = <int>[];
    final attach = AttachMealToTargetUseCase(now: () => now, currentTarget: () => current,
      loadMeal: (_) async => meal, saveLink: (_, id) async { saved.add(id); });
    await attach(mealTarget, 1);
    meal = null;
    await expectLater(attach(mealTarget, 1), throwsStateError);
    meal = const Meal(id: 1, name: 'Breakfast');
    current = null;
    await expectLater(attach(mealTarget, 1), throwsStateError);
    expect(saved, [1]);
  });

  test('closest meals are suggestions only and rescue treatments are excluded', () async {
    final useCase = LoadMealTargetCandidatesUseCase(loadMeals: (_, _) async => [
      Meal(id: 1, name: 'Earlier', plannedAt: mealTarget.createdAt.subtract(const Duration(hours: 1))),
      Meal(id: 2, name: 'Closest', plannedAt: mealTarget.createdAt.add(const Duration(minutes: 5))),
      Meal(id: 3, name: 'Rescue', plannedAt: mealTarget.createdAt, purpose: MealPurpose.lowTreatment),
    ]);
    expect((await useCase(mealTarget)).map((meal) => meal.id), [2, 1]);
  });

  test('disabled control or a stale card cannot send a stop', () async {
    var enabled = false;
    TemporaryTarget? current = target;
    var sends = 0;
    final stop = StopDashboardTargetUseCase(now: () => now, currentTarget: () => current,
      canControl: () => enabled, stop: (_) async { sends++; return DashboardTargetActionResult.sent; });
    expect(await stop(target), DashboardTargetActionResult.disabled);
    enabled = true;
    current = target.copyWith(nightscoutId: 'new-target');
    expect(await stop(target), DashboardTargetActionResult.changed);
    expect(sends, 0);
    current = target;
    expect(await stop(target), DashboardTargetActionResult.sent);
    expect(sends, 1);
  });
}

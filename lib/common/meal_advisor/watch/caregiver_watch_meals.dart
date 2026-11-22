import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/meal_status_flow.dart';
import '../../family_sync/family_access_scope.dart';
import '../../family_sync/family_planning_controller.dart';
import '../../family_sync/family_planning_session_provider.dart';
import '../../meal/meal_add_on_progress.dart';

typedef CaregiverWatchMeal = ({
  int id,
  String name,
  String status,
  int? plannedAtMs,
  MealAddOnProgress? addOnProgress,
  bool treatmentSurplus,
});

List<CaregiverWatchMeal> caregiverWatchMeals(
  Iterable<Map<String, dynamic>> rows, {
  required DateTime day,
}) {
  final active = <CaregiverWatchMeal>[];
  final plans = <CaregiverWatchMeal>[];
  for (final row in rows) {
    final payload = row['payload'];
    if (row['deleted'] == true || payload is! Map) continue;
    final id = payload['id'];
    final name = payload['name'];
    final status = payload['status'];
    if (id is! int || name is! String || status is! String) continue;
    final meal = (
      id: id,
      name: name,
      status: status,
      plannedAtMs: payload['planned_at'] as int?,
      addOnProgress: readMirroredAddOnProgress(payload['add_on_progress']),
      treatmentSurplus: payload['treatment_surplus'] == 1,
    );
    if (mealStatusBlocksAnotherMealActivation(status)) {
      active.add(meal);
    } else if (status == 'planned' && familyPlannedMealIsOnDay(payload, day)) {
      plans.add(meal);
    }
  }
  final visible = active.isEmpty ? plans : active;
  visible.sort((a, b) {
    final time = (a.plannedAtMs ?? 0).compareTo(b.plannedAtMs ?? 0);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
  return visible.take(30).toList(growable: false);
}

final caregiverWatchMealsProvider = Provider.autoDispose
    .family<List<CaregiverWatchMeal>?, String>((ref, uid) {
      final family = ref.watch(
        familyPlanningSessionProvider((
          uid: uid,
          home: true,
          mealId: null,
          context: false,
        )),
      );
      family.addListener(ref.invalidateSelf);
      ref.onDispose(() => family.removeListener(ref.invalidateSelf));
      if (!family.complete || !FamilyAccessScope(family).isCurrent) return null;
      return caregiverWatchMeals(family.ofKind('meals'), day: clock.now());
    });

typedef CaregiverWatchProgressKey = ({String uid, int mealId, String status});

final caregiverWatchProgressHistoryProvider = FutureProvider.autoDispose
    .family<List<({String status, int at})>, CaregiverWatchProgressKey>((
      ref,
      key,
    ) async {
      final family = ref.watch(
        familyPlanningSessionProvider((
          uid: key.uid,
          home: false,
          mealId: key.mealId,
          context: false,
        )),
      );
      await family.refreshAndWait(mirrorOnly: true);
      if (family.disposed ||
          !family.complete ||
          !FamilyAccessScope(family).isCurrent) {
        return const [];
      }
      return [
        for (final row in family.ofKind('mealHistory'))
          if (row['payload'] case {
            'meal_id': final int mealId,
            'status': final String status,
            'created_at': final int at,
          })
            if (mealId == key.mealId) (status: status, at: at),
      ];
    });

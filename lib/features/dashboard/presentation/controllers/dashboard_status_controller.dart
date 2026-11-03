import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../../core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../activity/common/controllers/activity_actions_controller.dart';
import '../../../activity/common/controllers/serialized_status_action_controller.dart';
import '../../../activity/data/drafts/activity_log_draft.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../common/temporary_targets/meal_target_links.dart';
import '../../data/providers/linked_target_meal_provider.dart';
import '../../data/providers/temporary_target_ui_provider.dart';
import '../../data/providers/time_now_provider.dart';
import '../../domain/models/dashboard_status_view_model.dart';
import '../../domain/use_cases/attach_activity_to_target_use_case.dart';
import '../../domain/use_cases/attach_meal_to_target_use_case.dart';
import '../../domain/use_cases/build_dashboard_status_use_case.dart';
import '../../domain/use_cases/load_meal_target_candidates_use_case.dart';
import '../../domain/use_cases/stop_dashboard_target_use_case.dart';

final dashboardStatusViewModelProvider =
    Provider.autoDispose<DashboardStatusViewModel>((ref) {
      final activity = ref.watch(getPendingActivityProvider);
      return const BuildDashboardStatusUseCase()(
        now: ref.watch(timeNowProvider).asData?.value ?? clock.now(),
        pendingActivity: activity.asData?.value,
        target: ref.watch(temporaryTargetUiProvider),
        loading: activity.isLoading,
      );
    });

final dashboardTargetControlEnabledProvider = Provider.autoDispose<bool>((ref) {
  final preferences = ref.watch(sharedPrefsProvider).asData?.value;
  return preferences != null &&
      ref.watch(tempTargetServiceProvider).isEnabled(preferences);
});

final mealTargetCandidatesProvider = FutureProvider.autoDispose
    .family<List<Meal>, TemporaryTarget>((ref, target) {
      final db = ref.watch(databaseProvider);
      return LoadMealTargetCandidatesUseCase(
        loadMeals: (from, until) async =>
            (await db.mealDao.getMealsBetween(from, until)).toDomainList(),
      )(target);
    });

final dashboardStatusControllerProvider =
    NotifierProvider.autoDispose<DashboardStatusController, AsyncValue<void>>(
      DashboardStatusController.new,
    );

class DashboardStatusController extends SerializedStatusActionController {
  Future<void> attachActivity(TemporaryTarget target, ActivityLogDraft draft) =>
      execute(() async {
        await AttachActivityToTargetUseCase(
          now: clock.now,
          currentTarget: () => ref.read(temporaryTargetUiProvider),
          saveStartedActivity: (value) => ref
              .read(activityActionsControllerProvider.notifier)
              .saveStarted(value),
        )(target, draft);
        if (ref.mounted) ref.invalidate(timeNowProvider);
      });

  Future<void> attachMeal(TemporaryTarget target, int mealId) =>
      execute(() async {
        final prefs = await ref.read(sharedPrefsProvider.future);
        final source = prefs.getString(nightscoutUrlKey)?.trim() ?? '';
        if (source.isEmpty) throw StateError('No Nightscout source');
        final db = ref.read(databaseProvider);
        await AttachMealToTargetUseCase(
          now: clock.now,
          currentTarget: () => ref.read(temporaryTargetUiProvider),
          loadMeal: (id) async =>
              (await db.mealDao.getMealById(id))?.toDomain(),
          saveLink: (selected, id) async {
            if (source != prefs.getString(nightscoutUrlKey)?.trim()) {
              throw StateError('Nightscout source changed');
            }
            await MealTargetLinks(prefs).attach(source, selected, id);
          },
        )(target, mealId);
        if (ref.mounted) ref.invalidate(linkedTargetMealProvider(target));
      });

  Future<DashboardTargetActionResult> stopTarget(TemporaryTarget target) =>
      execute(() async {
        final prefs = await ref.read(sharedPrefsProvider.future);
        final service = ref.read(tempTargetServiceProvider);
        final result = await StopDashboardTargetUseCase(
          now: clock.now,
          currentTarget: () => ref.read(temporaryTargetUiProvider),
          canControl: () => service.isEnabled(prefs),
          stop: (selected) async => switch (await service.stopDisplayedTarget(
            selected,
            source: prefs.getString(nightscoutUrlKey)?.trim() ?? '',
          )) {
            TempTargetSendResult.sent => DashboardTargetActionResult.sent,
            TempTargetSendResult.expired => DashboardTargetActionResult.changed,
            _ => DashboardTargetActionResult.failed,
          },
        )(target);
        if (ref.mounted &&
            result == DashboardTargetActionResult.sent &&
            ref.read(temporaryTargetUiProvider) == target) {
          ref.read(temporaryTargetUiProvider.notifier).clear();
        }
        return result;
      });
}

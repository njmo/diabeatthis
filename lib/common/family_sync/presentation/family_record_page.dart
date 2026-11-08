import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/activity/data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import '../../../features/activity/data/drafts/activity_draft.dart';
import '../../../features/activity/data/models/activity_log_analysis_data.dart';
import '../../../features/activity/presentation/widgets/activity_definition_sheet.dart';
import '../../../features/activity/presentation/widgets/activity_log_body.dart';
import '../../../features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import '../../../features/meals/data/models/meal_analysis_data.dart';
import '../../../features/meals/presentation/screens/meal_page_body.dart';
import '../../auth/google_authentication_providers.dart';
import '../../l10n/language.dart';
import '../../presentation/collections/controllers/caregiver_activities_controller.dart';
import '../../presentation/collections/controllers/caregiver_activity_logs_controller.dart';
import '../../presentation/details/activity_definition_view.dart';
import '../../presentation/details/activity_history_statistics.dart';
import '../../presentation/details/activity_log_preview_controller.dart';
import '../../presentation/details/ingredient_details_view.dart';
import '../../presentation/details/ingredient_preview_controller.dart';
import '../../presentation/details/meal_preview_controller.dart';
import '../../presentation/details/nightscout_record_history.dart';
import '../../routing/owned_route_registry.dart';
import '../family_access_scope.dart';
import '../family_planning_controller.dart';
import 'family_activity_catalog_scope.dart';
import 'family_activity_schedules.dart';
import 'family_scope_guard.dart';
import 'models/family_activity_log_details.dart';
import 'models/family_ingredient_details.dart';
import 'models/family_meal_details.dart';

/// Keeps an open preview bound to the same authenticated family/source as its list.
class FamilyRecordPage extends ConsumerWidget {
  FamilyRecordPage({
    super.key,
    required this.family,
    required this.kind,
    required this.id,
    this.editMeal,
  }) : recordScope = FamilyAccessScope(family),
       owner = family.owner,
       source = family.source,
       uid = family.uid;
  final FamilyPlanningController family;
  final FamilyAccessScope recordScope;
  final String kind;
  final int id;
  final String? owner;
  final String? source;
  final String? uid;
  final VoidCallback? editMeal;

  static Future<void> open(
    BuildContext context,
    FamilyPlanningController family,
    String kind,
    int id, {
    VoidCallback? editMeal,
    FamilyAccessScope? scope,
  }) {
    final pinned = scope ?? FamilyAccessScope(family);
    if (!pinned.isCurrent || !family.complete) return Future<void>.value();
    final page = FamilyRecordPage(
      family: family,
      kind: kind,
      id: id,
      editMeal: editMeal,
    );
    final route = MaterialPageRoute<void>(builder: (_) => page);
    OwnedRouteRegistry.register(family, route);
    return Navigator.of(context)
        .push<void>(route)
        .whenComplete(() => OwnedRouteRegistry.unregister(family, route));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(googleAccountProvider);
    return FamilyScopeGuard(
      scope: recordScope,
      child: ListenableBuilder(
        listenable: family,
        builder: (context, _) {
          final valid =
              !family.disposed &&
              !family.failed &&
              family.uid == uid &&
              family.currentUid() == uid &&
              uid != null &&
              family.owner == owner &&
              family.source == source &&
              source != null;
          final rows = valid && family.complete
              ? family.rows.values.toList()
              : <Map<String, dynamic>>[];
          final record = rows
              .where(
                (r) =>
                    r['kind'] == kind &&
                    r['id'] == '$id' &&
                    r['deleted'] != true,
              )
              .firstOrNull;
          Widget? body;
          if (record != null) {
            if (kind == 'meals') {
              final state = FamilyMealDetails(
                rows,
              ).build(id, context.lang.mealPortionLabel);
              if (state != null) {
                Widget mealBody({MealAnalysisData? analysis}) =>
                    MealPageBody.controlled(
                      controller: CaregiverMealPreviewController(
                        analysis == null
                            ? state
                            : state.copyWith(analysis: analysis),
                        showAnalysis: analysis != null,
                        onOpenIngredient: (ingredientId) =>
                            FamilyRecordPage.open(
                              context,
                              family,
                              'ingredients',
                              ingredientId,
                              scope: recordScope,
                            ),
                      ),
                    );
                body = !state.details.meal.isEaten
                    ? mealBody()
                    : NightscoutRecordHistory<MealAnalysisData>(
                        key: ValueKey((uid, owner, source, kind, id)),
                        recordKey: (
                          id,
                          state.details.analysisTime,
                          state.details.observationWindow,
                          state.details.meal.status,
                        ),
                        load: (ref, history) => ref
                            .read(analyzeMealUseCaseProvider)
                            .call(
                              state.details,
                              history: history,
                              includeLocalContext: false,
                            ),
                        fallback: mealBody(),
                        showFallbackOnEmpty: true,
                        builder: (data) => mealBody(analysis: data),
                      );
              }
            } else if (kind == 'activityLogs') {
              final state = familyActivityLogDetails(rows, id);
              if (state != null) {
                final onOpenActivity =
                    rows.any(
                      (row) =>
                          row['kind'] == 'activities' &&
                          row['deleted'] != true &&
                          row['id'] == '${state.data.activityId}',
                    )
                    ? () => open(
                        context,
                        family,
                        'activities',
                        state.data.activityId,
                        scope: recordScope,
                      )
                    : null;
                body = state.data.endedAt == null
                    ? ActivityLogBody.controlled(
                        controller: CaregiverActivityLogPreviewController(
                          state,
                          onOpenActivity: onOpenActivity,
                        ),
                        onTimestampSelected: (_) {},
                      )
                    : NightscoutRecordHistory<ActivityLogAnalysisData>(
                        key: ValueKey((uid, owner, source, kind, id)),
                        recordKey: (
                          id,
                          state.data.startedAt,
                          state.data.endedAt,
                        ),
                        fallback: ActivityLogBody.controlled(
                          controller: CaregiverActivityLogPreviewController(
                            state,
                            onOpenActivity: onOpenActivity,
                          ),
                          onTimestampSelected: (_) {},
                        ),
                        load: (ref, history) => ref
                            .read(loadActivityLogAnalysisUseCaseProvider)
                            .call(
                              state.data,
                              history: history,
                              includeContext: true,
                              includeLocalContext: false,
                            ),
                        builder: (data) => ActivityHistoryStatistics(
                          state: state,
                          data: data,
                          onOpenActivity: onOpenActivity,
                        ),
                      );
              }
            } else if (kind == 'activities') {
              final activities = CaregiverActivitiesController(
                rows: rows,
                open: null,
                onRetry: family.refresh,
              );
              final activity = activities.state.items
                  .where((a) => a.id == id)
                  .firstOrNull;
              if (activity != null) {
                body = ActivityDefinitionView(
                  activity: activity,
                  plans: FamilyActivitySchedules(
                    scope: recordScope,
                    activity: activity,
                  ),
                  logs: CaregiverActivityLogsController(
                    rows: rows,
                    activityId: id,
                    onRetry: family.refresh,
                    open: (log) => open(
                      context,
                      family,
                      'activityLogs',
                      log.id,
                      scope: recordScope,
                    ),
                  ),
                );
              }
            } else if (kind == 'ingredients') {
              final data = FamilyIngredientDetails(rows).build(id);
              if (data != null) {
                body = IngredientDetailsView(
                  controller: CaregiverIngredientPreviewController(
                    data,
                    showConfidence: data.origin != null,
                    onOpenMeal: (mealId) => open(
                      context,
                      family,
                      'meals',
                      mealId,
                      scope: recordScope,
                    ),
                  ),
                );
              }
            }
          }
          final payload = record?['payload'] as Map?;
          final canEdit =
              valid &&
              kind == 'meals' &&
              family.complete &&
              !family.locked('meals', id) &&
              payload?['status'] == 'planned' &&
              payload?['purpose'] == 'meal' &&
              rows
                  .where(
                    (r) =>
                        r['kind'] == 'mealIngredients' &&
                        r['deleted'] != true &&
                        (r['payload'] as Map)['meal_id'] == id,
                  )
                  .every(
                    (r) =>
                        (r['payload'] as Map)['grams_per_portion_used'] != null,
                  );
          return Scaffold(
            appBar: AppBar(
              title: Text(
                kind == 'meals'
                    ? context.lang.mealReviewPageTitle
                    : kind == 'ingredients'
                    ? (payload?['is_reference'] == 1
                          ? context.lang.ingredientReferenceBadge
                          : context.lang.ingredientDetailsTitle)
                    : kind == 'activities'
                    ? context.lang.activityTitle
                    : context.lang.activityLogTitle,
              ),
              actions: [
                if (kind == 'activities' &&
                    record != null &&
                    family.complete &&
                    !family.locked('activities', id))
                  FamilyActivityCatalogScope(
                    scope: recordScope,
                    child: Builder(
                      builder: (context) => IconButton(
                        tooltip: context.lang.activityEditTooltip,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          if (!recordScope.isCurrent ||
                              !family.complete ||
                              family.locked('activities', id)) {
                            return;
                          }
                          final p =
                              family.rows['activities/$id']?['payload'] as Map?;
                          if (p == null) return;
                          showActivityDefinitionSheet(
                            context,
                            initialDraft: ActivityDraft.existing(
                              id: id,
                              name: p['name'] as String,
                              percentagePre: p['percentage_pre'] as int,
                              percentagePost: p['percentage_post'] as int,
                              durationMinutes: p['duration_minutes'] as int?,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (canEdit && editMeal != null)
                  IconButton(
                    tooltip: context.lang.familyPlanEdit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      if (recordScope.isCurrent && family.complete) editMeal!();
                    },
                  ),
              ],
            ),
            body:
                body ??
                Center(
                  child: Text(
                    valid
                        ? context.lang.familyPlanWaitingForChild
                        : context.lang.familyPlanFailed,
                  ),
                ),
          );
        },
      ),
    );
  }
}

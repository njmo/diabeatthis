import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/activity/presentation/widgets/activity_log_body.dart';
import '../../../features/meals/presentation/screens/meal_page_body.dart';
import '../../auth/google_authentication_providers.dart';
import '../../l10n/language.dart';
import '../../presentation/collections/controllers/caregiver_activities_controller.dart';
import '../../presentation/collections/controllers/caregiver_activity_logs_controller.dart';
import '../../presentation/details/activity_definition_view.dart';
import '../../presentation/details/activity_log_preview_controller.dart';
import '../../presentation/details/meal_preview_controller.dart';
import '../family_planning_controller.dart';
import 'family_ingredient_details_dialog.dart';
import 'models/family_activity_log_details.dart';
import 'models/family_meal_details.dart';

/// Keeps an open preview bound to the same authenticated family/source as its list.
class FamilyRecordPage extends ConsumerWidget {
  FamilyRecordPage({
    super.key,
    required this.family,
    required this.kind,
    required this.id,
    this.editMeal,
  }) : owner = family.owner,
       source = family.source,
       uid = family.uid;
  final FamilyPlanningController family;
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
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => FamilyRecordPage(
        family: family,
        kind: kind,
        id: id,
        editMeal: editMeal,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(googleAccountProvider);
    return ListenableBuilder(
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
                  r['kind'] == kind && r['id'] == '$id' && r['deleted'] != true,
            )
            .firstOrNull;
        Widget? body;
        if (record != null) {
          if (kind == 'meals') {
            final state = FamilyMealDetails(
              rows,
            ).build(id, context.lang.mealPortionLabel);
            if (state != null) {
              body = MealPageBody.controlled(
                controller: CaregiverMealPreviewController(state),
              );
            }
          } else if (kind == 'activityLogs') {
            final state = familyActivityLogDetails(rows, id);
            if (state != null) {
              body = ActivityLogBody.controlled(
                controller: CaregiverActivityLogPreviewController(state),
                onTimestampSelected: (_) {},
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
                logs: CaregiverActivityLogsController(
                  rows: rows,
                  activityId: id,
                  onRetry: family.refresh,
                  open: (log) => open(context, family, 'activityLogs', log.id),
                ),
              );
            }
          } else if (kind == 'ingredients') {
            body = FamilyIngredientDetailsDialog(
              data: Map<String, dynamic>.from(record['payload'] as Map),
            );
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
                  ? context.lang.managementIngredientsTab
                  : kind == 'activities'
                  ? context.lang.activityTitle
                  : context.lang.activityLogTitle,
            ),
            actions: [
              if (canEdit && editMeal != null)
                IconButton(
                  tooltip: context.lang.familyPlanEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: editMeal,
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
    );
  }
}

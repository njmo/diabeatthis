import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../meal/meal_category.dart';
import '../../presentation/collections/controllers/caregiver_activities_controller.dart';
import '../../presentation/collections/controllers/caregiver_activity_logs_controller.dart';
import '../../presentation/collections/controllers/caregiver_ingredients_controller.dart';
import '../../presentation/collections/controllers/caregiver_meals_controller.dart';
import '../../presentation/collections/views/activities_view.dart';
import '../../presentation/collections/views/activity_logs_view.dart';
import '../../presentation/collections/views/ingredients_view.dart';
import '../../presentation/collections/views/meals_view.dart';
import '../../widgets/meal_category_field.dart';
import '../../widgets/search_text_field.dart';
import '../family_planning_controller.dart';
import '../family_planning_view.dart';
import 'family_ingredient_catalog_section.dart';
import 'family_plan_request_card.dart';
import 'family_planned_activity_card.dart';
import 'family_record_page.dart';

typedef FamilyPlanEditor =
    Future<void> Function(
      String type, {
      int? targetId,
      Map<String, dynamic>? initial,
    });

/// Family bindings only; all four collections use the same views as local mode.
class FamilyCollectionsBody extends StatefulWidget {
  const FamilyCollectionsBody({
    super.key,
    required this.family,
    required this.view,
    required this.enabled,
    required this.edit,
    required this.mealValues,
  });
  final FamilyPlanningController family;
  final FamilyPlanningView view;
  final bool enabled;
  final FamilyPlanEditor edit;
  final Map<String, dynamic> Function(Map) mealValues;
  @override
  State<FamilyCollectionsBody> createState() => FamilyCollectionsBodyState();
}

class FamilyCollectionsBodyState extends State<FamilyCollectionsBody> {
  final search = TextEditingController();
  String query = '';
  MealCategory? category;
  @override
  void didUpdateWidget(covariant FamilyCollectionsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) {
      query = '';
      search.clear();
      category = null;
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.family;
    final rows = family.rows.values.toList();
    final loading = family.busy && rows.isEmpty;
    void openMeal(int id) => FamilyRecordPage.open(
      context,
      family,
      'meals',
      id,
      editMeal: () {
        final payload = family.rows['meals/$id']?['payload'] as Map?;
        if (payload != null && widget.enabled && !family.locked('meals', id)) {
          widget.edit(
            'updateMeal',
            targetId: id,
            initial: widget.mealValues(payload),
          );
        }
      },
    );
    if (widget.view == FamilyPlanningView.ingredients) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FamilyIngredientCatalogSection(rows: rows, searchOnly: true),
          ),
          Expanded(
            child: IngredientListContent.controlled(
              queryController: search,
              onQueryChanged: (v) => setState(() => query = v),
              controller: CaregiverIngredientsController(
                rows: rows,
                query: query,
                loading: loading,
                failed: family.failed,
                onRetry: family.refresh,
                open: (item) => FamilyRecordPage.open(
                  context,
                  family,
                  'ingredients',
                  item.id,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (widget.view == FamilyPlanningView.activityCatalog) {
      return ActivitiesView(
        controller: CaregiverActivitiesController(
          rows: rows,
          loading: loading,
          failed: family.failed,
          onRetry: family.refresh,
          open: (item) =>
              FamilyRecordPage.open(context, family, 'activities', item.id),
        ),
      );
    }
    if (widget.view == FamilyPlanningView.meals) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SearchTextField(
              controller: search,
              hintText: context.lang.mealSearchHint,
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MealCategoryField(
              value: category,
              filter: true,
              onChanged: (v) => setState(() => category = v),
            ),
          ),
          Expanded(
            child: MealListContent.controlled(
              header: [
                for (final plan in family.plans.where(
                  (p) => (p['type'] as String).endsWith('Meal'),
                ))
                  FamilyPlanRequestCard(
                    plan: plan,
                    onRetry: widget.enabled
                        ? () => widget.edit(
                            plan['type'] as String,
                            targetId: plan['targetId'] as int?,
                            initial: Map<String, dynamic>.from(
                              plan['values'] as Map,
                            ),
                          )
                        : null,
                  ),
              ],
              controller: CaregiverMealsController(
                rows: rows,
                query: query,
                category: category,
                loading: loading,
                failed: family.failed,
                onRetry: family.refresh,
                open: (item) => openMeal(item.id),
              ),
            ),
          ),
        ],
      );
    }
    final activities = CaregiverActivitiesController(
      rows: rows,
      open: null,
      onRetry: family.refresh,
    ).state.items;
    return ActivityLogsView(
      controller: CaregiverActivityLogsController(
        rows: rows,
        loading: loading,
        failed: family.failed,
        onRetry: family.refresh,
        open: (item) =>
            FamilyRecordPage.open(context, family, 'activityLogs', item.id),
      ),
      header: [
        for (final row in family.ofKind('activityOccurrences').where((r) {
          final p = r['payload'] as Map;
          final log =
              family.rows['activityLogs/${p['activity_log_id']}']?['payload']
                  as Map?;
          return ['pending', 'planned'].contains(p['status']) &&
              (log == null ||
                  (log['started_at'] as int) >
                      DateTime.now().millisecondsSinceEpoch);
        }))
          FamilyPlannedActivityCard(
            payload: row['payload'] as Map,
            name:
                activities
                    .where(
                      (a) => a.id == (row['payload'] as Map)['activity_id'],
                    )
                    .firstOrNull
                    ?.name ??
                context.lang.familyPlanActivity,
            locked: family.locked(
              'activityOccurrences',
              (row['payload'] as Map)['id'] as int,
            ),
            monitoring: family.monitored(
              'activityOccurrences',
              (row['payload'] as Map)['id'] as int,
            ),
            onConfirm: !widget.enabled
                ? null
                : () => widget.edit(
                    'confirmActivity',
                    targetId: (row['payload'] as Map)['id'] as int,
                  ),
            onMove: !widget.enabled
                ? null
                : () => widget.edit(
                    'moveActivity',
                    targetId: (row['payload'] as Map)['id'] as int,
                    initial: {
                      'startedAt': (row['payload'] as Map)['started_at'],
                    },
                  ),
          ),
        for (final plan in family.plans.where(
          (p) => !(p['type'] as String).endsWith('Meal'),
        ))
          FamilyPlanRequestCard(
            plan: plan,
            onRetry: widget.enabled
                ? () => widget.edit(
                    plan['type'] as String,
                    targetId: plan['targetId'] as int?,
                    initial: Map<String, dynamic>.from(plan['values'] as Map),
                  )
                : null,
          ),
      ],
    );
  }
}

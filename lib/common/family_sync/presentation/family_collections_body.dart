import 'package:flutter/material.dart';

import '../../../features/activity/presentation/widgets/activity_definition_sheet.dart';
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
import '../../presentation/widgets/activity_upcoming_sessions_button.dart';
import '../../widgets/meal_category_field.dart';
import '../../widgets/search_text_field.dart';
import '../family_access_scope.dart';
import '../family_planning_controller.dart';
import '../family_planning_view.dart';
import 'family_activity_catalog_plan_card.dart';
import 'family_activity_catalog_scope.dart';
import 'family_ingredient_catalog_section.dart';
import 'family_plan_status_card.dart';
import 'family_record_page.dart';
import 'family_scope_guard.dart';
import 'family_upcoming_activities.dart';

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
    final access = FamilyAccessScope(family);
    final rows = family.rows.values.toList();
    final loading = family.busy && rows.isEmpty;
    void openMeal(int id) => FamilyRecordPage.open(
      context,
      family,
      'meals',
      id,
      scope: access,
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
            child: FamilyIngredientCatalogSection(
              rows: rows,
              searchOnly: true,
              family: family,
            ),
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
                  scope: access,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (widget.view == FamilyPlanningView.activityCatalog) {
      final scope = FamilyAccessScope(family);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FamilyActivityCatalogScope(
            scope: scope,
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(context.lang.activityCreateTitle),
                  onPressed: !widget.enabled
                      ? null
                      : () => showActivityDefinitionSheet(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: ActivitiesView(
              header: [
                for (final plan in family.plans.where(
                  (p) =>
                      isActivityCatalogPlan(p) &&
                      ['pending', 'rejected'].contains(p['status']),
                ))
                  FamilyActivityCatalogPlanCard(scope: scope, plan: plan),
              ],
              controller: CaregiverActivitiesController(
                rows: rows,
                loading: loading,
                failed: family.failed,
                onRetry: family.refresh,
                open: (item) => FamilyRecordPage.open(
                  context,
                  family,
                  'activities',
                  item.id,
                  scope: scope,
                ),
              ),
            ),
          ),
        ],
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
              statusLabelFor: (context, meal) => familyPlanRecordLabel(
                context,
                family.plans,
                'meals',
                meal.id,
              ),
              retryFor: (meal) => widget.enabled
                  ? familyPlanRetryForRecord(
                      family.plans,
                      'meals',
                      meal.id,
                      widget.edit,
                    )
                  : null,
              header: [
                for (final plan in family.plans.where(
                  (p) =>
                      (p['type'] as String).endsWith('Meal') &&
                      showFamilyPlanStatus(p, rows),
                ))
                  FamilyPlanStatusCard(
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
    return ActivityLogsView(
      controller: CaregiverActivityLogsController(
        rows: rows,
        loading: loading,
        failed: family.failed,
        onRetry: family.refresh,
        open: (item) => FamilyRecordPage.open(
          context,
          family,
          'activityLogs',
          item.id,
          scope: access,
        ),
      ),
      header: [
        ActivityUpcomingSessionsButton(
          routeGuard: (child) => FamilyScopeGuard(scope: access, child: child),
          contentBuilder: (_) =>
              FamilyUpcomingActivities(scope: access, edit: widget.edit),
        ),
        for (final plan in family.plans.where(
          (p) =>
              !(p['type'] as String).endsWith('Meal') &&
              !isUpcomingFamilyActivityPlan(p) &&
              ![
                'createActivity',
                'updateActivity',
                'createActivitySchedule',
                'setActivityScheduleEnabled',
              ].contains(p['type']) &&
              showFamilyPlanStatus(p, rows),
        ))
          FamilyPlanStatusCard(
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/family_sync/family_access_scope.dart';
import '../../../../common/family_sync/family_planning_view.dart';
import '../../../../common/family_sync/presentation/family_planning_page.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/meal_advisor/demo/meal_decision_demo_controller.dart';
import '../../../../common/meal_advisor/demo/meal_decision_demo_request.dart';
import '../../../../common/meal_advisor/meal_decision_preferences_provider.dart';
import '../../../../common/meal_advisor/presentation/demo/caregiver_meal_decision_demo_inbox.dart';
import '../../../../common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
import '../../../../common/presentation/dashboard/dashboard_shell.dart';
import 'caregiver_dashboard_fab.dart';
import 'caregiver_data_error_notice.dart';
import 'caregiver_nightscout_panel.dart';

class CaregiverDashboard extends ConsumerStatefulWidget {
  const CaregiverDashboard({super.key});
  @override
  ConsumerState<CaregiverDashboard> createState() => CaregiverDashboardState();
}

class CaregiverDashboardState extends ConsumerState<CaregiverDashboard> {
  final planning = GlobalKey<FamilyPlanningPageState>();
  int destination = 0;
  int historyCategory = 0;
  int catalogCategory = 0;
  Future<void> simulateRequest() async {
    final family = planning.currentState?.controller;
    final scope = family == null ? null : FamilyAccessScope(family);
    final planned = scope?.isCurrent == true && family!.complete
        ? (family
                  .ofKind('meals')
                  .where(
                    (row) => (row['payload'] as Map)['status'] == 'planned',
                  )
                  .firstOrNull?['payload']
              as Map?)
        : null;
    await ref
        .read(mealDecisionDemoControllerProvider.notifier)
        .send(
          caregiverMealDecisionDemoKey,
          planned?['name'] as String? ??
              context.lang.mealDecisionDemoSampleMeal,
          mealId: planned?['id'] as int?,
          childOwner: planned == null ? null : scope?.owner,
          mirrorSource: planned == null ? null : scope?.source,
        );
    if (!mounted) return;
    final request = ref.read(
      mealDecisionDemoControllerProvider,
    )[caregiverMealDecisionDemoKey];
    if (request == null ||
        !{
          MealDecisionDemoStatus.waiting,
          MealDecisionDemoStatus.answered,
        }.contains(request.status)) {
      return;
    }
    final name = ref.read(googleAccountProvider).asData?.value?.label;
    final caregiver = name == null || name.trim().isEmpty
        ? context.lang.mealDecisionDemoCaregiver
        : name;
    Future<void> openRequest() async {
      if (!mounted ||
          ref.read(mealDecisionDemoControllerProvider)[request.key]?.id !=
              request.id) {
        return;
      }
      await showCaregiverMealDecisionDemo(
        context,
        requestKey: request.key,
        requestId: request.id,
        caregiverName: caregiver,
        familyScope: request.mealId == null ? null : scope,
      );
    }

    if (request.status == MealDecisionDemoStatus.answered) {
      await openRequest();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.lang.mealDecisionDemoNewRequest),
        action: SnackBarAction(
          label: context.lang.mealDecisionDemoOpen,
          onPressed: openRequest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = destination == 2 ? historyCategory : catalogCategory;
    final view = switch (destination) {
      0 => FamilyPlanningView.home,
      1 => FamilyPlanningView.day,
      2 =>
        category == 0
            ? FamilyPlanningView.meals
            : FamilyPlanningView.activities,
      _ =>
        category == 0
            ? FamilyPlanningView.ingredients
            : FamilyPlanningView.activityCatalog,
    };
    return DashboardShell(
      destination: destination,
      category: category,
      onDestination: (index) => setState(() => destination = index),
      onCategory: (index) => setState(() {
        if (destination == 2) {
          historyCategory = index;
        } else {
          catalogCategory = index;
        }
      }),
      actions: CaregiverDashboardFab(
        onSimulateRequest:
            ref.watch(mealDecisionPreferencesProvider).caregiverResponsesEnabled
            ? simulateRequest
            : null,
        onPhoto: () => planning.currentState?.planFromPhoto(),
        onMeal: () => planning.currentState?.edit('createMeal'),
        onActivity: () => planning.currentState?.edit('planActivity'),
      ),
      body: FamilyPlanningPage(
        key: planning,
        embedded: true,
        view: view,
        headerBuilder: destination == 0
            ? (busy, failed, ready) => Column(
                children: [
                  const CaregiverDataErrorNotice(),
                  CaregiverNightscoutPanel(
                    syncBusy: busy,
                    syncFailed: failed,
                    syncReady: ready,
                  ),
                  CaregiverMealDecisionDemoInbox(
                    family: () => planning.currentState?.controller,
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

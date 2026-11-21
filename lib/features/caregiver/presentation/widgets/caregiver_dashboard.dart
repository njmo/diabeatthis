import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/family/family_providers.dart';
import '../../../../common/family/presentation/family_management_page.dart';
import '../../../../common/family_chat/presentation/family_chat_page.dart';
import '../../../../common/family_sync/family_planning_view.dart';
import '../../../../common/family_sync/presentation/family_planning_page.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/dashboard/dashboard_shell.dart';
import '../../../../common/routing/form_bottom_sheet_route.dart';
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

  bool _requestOpen = false;

  Future<void> _requestLowTreatment() async {
    if (_requestOpen) return;
    _requestOpen = true;
    try {
      await showFamilyLowTreatmentFromDashboard(context, ref);
    } finally {
      _requestOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
    final pending = uid == null
        ? null
        : ref.watch(secureFamilyStatusProvider(uid)).asData?.value.pending;
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
        onPhoto: () => planning.currentState?.planFromPhoto(),
        onMeal: () => planning.currentState?.edit('createMeal'),
        onActivity: () => planning.currentState?.edit('planActivity'),
        onLowTreatment: _requestLowTreatment,
      ),
      body: Column(
        children: [
          if (pending != null)
            MaterialBanner(
              content: Text(context.lang.familyApprovalTitle),
              actions: [
                TextButton(
                  onPressed: () => showFormBottomSheet<void>(
                    context,
                    const FamilyManagementPage(),
                    initialContentHeight: 240,
                  ),
                  child: Text(context.lang.familyManageAction),
                ),
              ],
            ),
          Expanded(
            child: FamilyPlanningPage(
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
                          onLowTreatment: _requestLowTreatment,
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

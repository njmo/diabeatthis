import 'package:flutter/material.dart';

import '../../../../common/family_sync/family_planning_view.dart';
import '../../../../common/family_sync/presentation/family_planning_page.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/compact_category_selector.dart';
import '../../../dashboard/presentation/widgets/dashboard_bottom_bar.dart';
import '../../../dashboard/presentation/widgets/dashboard_greeting.dart';
import '../../../dashboard/presentation/widgets/dashboard_user_menu.dart';
import 'caregiver_dashboard_fab.dart';
import 'caregiver_data_error_notice.dart';
import 'caregiver_nightscout_panel.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});
  @override
  State<CaregiverDashboard> createState() => CaregiverDashboardState();
}

class CaregiverDashboardState extends State<CaregiverDashboard> {
  final planning = GlobalKey<FamilyPlanningPageState>();
  int destination = 0;
  int historyCategory = 0;
  int catalogCategory = 0;
  @override
  Widget build(BuildContext context) {
    final collection = destination >= 2;
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
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        bottom: destination == 0
            ? const PreferredSize(
                preferredSize: Size.fromHeight(8),
                child: SizedBox(height: 8),
              )
            : null,
        title: destination == 0
            ? const DashboardGreeting()
            : Text(
                destination == 1
                    ? context.lang.dashboardDayTab
                    : destination == 2
                    ? context.lang.dashboardHistoryTab
                    : context.lang.dashboardCatalogTab,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (collection)
            CompactCategorySelector(
              labels: [
                destination == 2
                    ? context.lang.managementMealsTab
                    : context.lang.managementIngredientsTab,
                context.lang.managementActivitiesTab,
              ],
              icons: [
                destination == 2
                    ? Icons.restaurant_outlined
                    : Icons.egg_alt_outlined,
                Icons.directions_run,
              ],
              selectedIndex: category,
              onSelected: (index) => setState(() {
                if (destination == 2) {
                  historyCategory = index;
                } else {
                  catalogCategory = index;
                }
              }),
            ),
          if (destination == 0) const DashboardUserMenu(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: DashboardBottomBar(
        selectedIndex: destination,
        onSelected: (index) => setState(() => destination = index),
      ),
      floatingActionButton: CaregiverDashboardFab(
        onPhoto: () => planning.currentState?.planFromPhoto(),
        onMeal: () => planning.currentState?.edit('createMeal'),
        onActivity: () => planning.currentState?.edit('planActivity'),
      ),
      body: FamilyPlanningPage(
        key: planning,
        embedded: true,
        view: view,
        header: destination == 0
            ? const Column(
                children: [
                  CaregiverDataErrorNotice(),
                  CaregiverNightscoutPanel(),
                ],
              )
            : null,
      ),
    );
  }
}

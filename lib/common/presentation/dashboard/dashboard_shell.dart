import 'package:flutter/material.dart';

import '../../../features/dashboard/presentation/widgets/dashboard_bottom_bar.dart';
import '../../../features/dashboard/presentation/widgets/dashboard_greeting.dart';
import '../../../features/dashboard/presentation/widgets/dashboard_user_menu.dart';
import '../../l10n/language.dart';
import '../../widgets/compact_category_selector.dart';

/// Both application modes use one navigation frame and one set of styles.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.destination,
    required this.category,
    required this.onDestination,
    required this.onCategory,
    required this.actions,
    required this.body,
  });
  final int destination;
  final int category;
  final ValueChanged<int> onDestination;
  final ValueChanged<int> onCategory;
  final Widget actions;
  final Widget body;
  @override
  Widget build(BuildContext context) => Scaffold(
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
        if (destination >= 2)
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
            onSelected: onCategory,
          ),
        if (destination == 0) const DashboardUserMenu(),
        const SizedBox(width: 8),
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: DashboardBottomBar(
      selectedIndex: destination,
      onSelected: onDestination,
    ),
    floatingActionButton: actions,
    body: body,
  );
}

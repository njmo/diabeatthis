import 'package:flutter/material.dart';

import '../../../core/notifications/in_app/widgets/notification_inbox.dart';
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
    this.dayStatus,
    this.secondaryAction,
  });
  final int destination;
  final int category;
  final ValueChanged<int> onDestination;
  final ValueChanged<int> onCategory;
  final Widget actions;
  final Widget body;
  final Widget? dayStatus;
  final Widget? secondaryAction;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    backgroundColor: destination == 0
        ? Theme.of(context).colorScheme.surface
        : null,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: destination == 0 ? kMinInteractiveDimension : null,
      titleSpacing: destination == 0 ? 10 : null,
      bottom: destination == 0
          ? const PreferredSize(
              preferredSize: Size.fromHeight(4),
              child: SizedBox(height: 4),
            )
          : null,
      title: destination == 0
          ? const Row(
              children: [
                Expanded(child: DashboardGreeting()),
                NotificationInboxButton(),
                DashboardUserMenu(),
              ],
            )
          : Row(
              children: [
                Flexible(
                  child: Text(
                    destination == 1
                        ? context.lang.dashboardDayTab
                        : destination == 2
                        ? context.lang.dashboardHistoryTab
                        : context.lang.dashboardCatalogTab,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (destination == 1 && dayStatus != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: dayStatus!),
                ],
              ],
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
        if (destination != 0) const SizedBox(width: 8),
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: DashboardBottomBar(
      selectedIndex: destination,
      onSelected: onDestination,
    ),
    floatingActionButton: actions,
    body: secondaryAction == null
        ? body
        : Stack(
            children: [
              Positioned.fill(child: body),
              PositionedDirectional(
                end: 16,
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
                child: secondaryAction!,
              ),
            ],
          ),
  );
}

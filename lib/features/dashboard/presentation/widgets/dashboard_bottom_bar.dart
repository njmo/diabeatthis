import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'dashboard_destination.dart';

class DashboardBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const DashboardBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => BottomAppBar(
    shape: const CircularNotchedRectangle(),
    notchMargin: 8,
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: [
        Expanded(
          child: DashboardDestination(
            label: context.lang.managementMealsTab,
            icon: Icons.restaurant_outlined,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
        ),
        const SizedBox(width: 72),
        Expanded(
          child: DashboardDestination(
            label: context.lang.dashboardDayTab,
            icon: Icons.today_outlined,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
        ),
      ],
    ),
  );
}

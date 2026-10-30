import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'dashboard_destination.dart';
import 'dashboard_navigation_outline.dart';
import 'dashboard_navigation_shape.dart';

double dashboardBottomBarHeight(BuildContext context) =>
    64 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 1.4;

class DashboardBottomBar extends StatelessWidget {
  const DashboardBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final destinations = [
      (context.lang.dashboardHomeTab, Icons.home_outlined),
      (context.lang.dashboardDayTab, Icons.today_outlined),
      (context.lang.dashboardHistoryTab, Icons.history),
      (context.lang.dashboardCatalogTab, Icons.menu_book_outlined),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: CustomPaint(
            foregroundPainter: DashboardNavigationOutline(
              geometry: Scaffold.geometryOf(context),
              color: Theme.of(context).colorScheme.outlineVariant,
              leftInset: 12 + MediaQuery.paddingOf(context).left,
            ),
            child: BottomAppBar(
              color: colors.surfaceContainer.withValues(
                alpha: dark ? 0.78 : 0.68,
              ),
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              height: dashboardBottomBarHeight(context),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              shape: DashboardNavigationShape(
                horizontalInset: 12 + MediaQuery.paddingOf(context).left,
              ),
              notchMargin: DashboardNavigationShape.notchMargin,
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < destinations.length;
                      index++
                    ) ...[
                      if (index == 2) const SizedBox(width: 64),
                      Expanded(
                        child: DashboardDestination(
                          label: destinations[index].$1,
                          icon: destinations[index].$2,
                          selected: selectedIndex == index,
                          onTap: () => onSelected(index),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

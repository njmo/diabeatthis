import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common/l10n/language.dart';
import 'dashboard_navigation_group.dart';
import 'dashboard_navigation_outline.dart';
import 'dashboard_navigation_shape.dart';

double dashboardBottomBarHeight(BuildContext context) =>
    56 + (MediaQuery.textScalerOf(context).scale(12.5) - 12.5);

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
      (context.lang.dashboardHomeTab, LucideIcons.panelsTopLeft),
      (context.lang.dashboardDayTab, LucideIcons.calendarRange),
      (context.lang.dashboardHistoryTab, LucideIcons.logs),
      (context.lang.dashboardCatalogTab, LucideIcons.library),
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
              color: (dark ? Colors.white : Colors.black).withValues(
                alpha: dark ? 0.08 : 0.10,
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: DashboardNavigationShape(
                horizontalInset: 12 + MediaQuery.paddingOf(context).left,
              ),
              notchMargin: DashboardNavigationShape.notchMargin,
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DashboardNavigationGroup(
                        destinations: destinations.sublist(0, 2),
                        startIndex: 0,
                        selectedIndex: selectedIndex,
                        onSelected: onSelected,
                      ),
                    ),
                    const SizedBox(width: 60),
                    Expanded(
                      child: DashboardNavigationGroup(
                        destinations: destinations.sublist(2),
                        startIndex: 2,
                        selectedIndex: selectedIndex,
                        onSelected: onSelected,
                      ),
                    ),
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

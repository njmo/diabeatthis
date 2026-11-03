import 'package:flutter/material.dart';

import 'dashboard_destination.dart';

/// Keeps each pair on its own side of the centered add button.
class DashboardNavigationGroup extends StatelessWidget {
  const DashboardNavigationGroup({
    super.key,
    required this.destinations,
    required this.startIndex,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(String, IconData)> destinations;
  final int startIndex;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var offset = 0; offset < destinations.length; offset++)
        Expanded(
          flex: selectedIndex == startIndex + offset ? 2 : 1,
          child: DashboardDestination(
            label: destinations[offset].$1,
            icon: destinations[offset].$2,
            selected: selectedIndex == startIndex + offset,
            onTap: () => onSelected(startIndex + offset),
          ),
        ),
    ],
  );
}

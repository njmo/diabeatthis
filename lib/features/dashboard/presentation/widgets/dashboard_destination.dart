import 'package:flutter/material.dart';

import '../../../../common/widgets/compact_navigation_destination.dart';

class DashboardDestination extends StatelessWidget {
  const DashboardDestination({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CompactNavigationDestination(
    label: label,
    icon: icon,
    selected: selected,
    onTap: onTap,
  );
}

import 'package:flutter/material.dart';

import 'dashboard_spacing.dart';

/// The same entity-card inset is used by both home dashboards.
class DashboardCardPadding extends StatelessWidget {
  const DashboardCardPadding({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: enabled ? DashboardSpacing.cards : EdgeInsets.zero,
    child: child,
  );
}

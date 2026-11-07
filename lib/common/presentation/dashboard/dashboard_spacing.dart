import 'package:flutter/material.dart';

/// Shared geometry for both home dashboards; source adapters add no extra inset.
class DashboardSpacing {
  const DashboardSpacing._();

  static const cards = EdgeInsets.symmetric(horizontal: 12);

  static const panel = EdgeInsets.fromLTRB(12, 0, 12, 12);

  static EdgeInsets homeScroll(BuildContext context) =>
      EdgeInsets.only(bottom: 112 + MediaQuery.paddingOf(context).bottom);
}

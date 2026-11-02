import 'package:flutter/material.dart';

/// Keeps detail navigation reachable while the page contents scroll.
class DetailTabsHeader extends SliverPersistentHeaderDelegate {
  const DetailTabsHeader({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: color,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    ),
  );
  @override
  bool shouldRebuild(covariant DetailTabsHeader oldDelegate) =>
      oldDelegate.child != child || oldDelegate.color != color;
}

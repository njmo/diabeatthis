import 'package:flutter/material.dart';

/// Shared navigation for detail pages such as ingredients and meals.
class DetailTabs extends StatelessWidget {
  const DetailTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.scrollable = false,
  });
  final TabController controller;
  final List<String> labels;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TabBar(
      controller: controller,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
      labelColor: colors.primary,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      splashBorderRadius: BorderRadius.circular(18),
      labelPadding: EdgeInsets.symmetric(horizontal: scrollable ? 16 : 8),
      indicator: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
      ),
      indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
      dividerColor: Colors.transparent,
      tabs: [for (final label in labels) Tab(text: label)],
    );
  }
}

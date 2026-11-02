import 'package:flutter/material.dart';

import 'section_surface.dart';

/// Shares content between an always-visible page section and a disclosure.
class DetailContentSection extends StatelessWidget {
  const DetailContentSection({
    super.key,
    required this.title,
    required this.children,
    this.collapsible = true,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.childrenPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });
  final Widget title;
  final List<Widget> children;
  final bool collapsible;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry childrenPadding;

  @override
  Widget build(BuildContext context) {
    if (!collapsible) {
      return SectionSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleMedium!,
              child: title,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
    }
    return Card(
      child: ExpansionTile(
        title: title,
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        childrenPadding: childrenPadding,
        children: children,
      ),
    );
  }
}

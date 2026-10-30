import 'package:flutter/material.dart';

class SectionSurface extends StatelessWidget {
  const SectionSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.45),
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}

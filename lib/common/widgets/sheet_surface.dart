import 'package:flutter/material.dart';

import 'application_corner_accent.dart';

/// A bounded or content-sized sheet with a fixed decorative corner.
class SheetSurface extends StatelessWidget {
  const SheetSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        const Positioned(
          top: -60,
          right: -100,
          width: 440,
          height: 380,
          child: ApplicationCornerAccent(),
        ),
        child,
      ],
    ),
  );
}

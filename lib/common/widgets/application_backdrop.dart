import 'package:flutter/material.dart';

import '../theme/application_accent_colors.dart';

/// One backdrop behind the navigator; opaque functional screens can opt out.
class ApplicationBackdrop extends StatelessWidget {
  const ApplicationBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -60,
            right: -100,
            width: 440,
            height: 380,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      ApplicationAccentColors.glow(theme.brightness).withValues(
                        alpha: theme.brightness == Brightness.dark ? .28 : .55,
                      ),
                      ApplicationAccentColors.glow(
                        theme.brightness,
                      ).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

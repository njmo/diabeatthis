import 'package:flutter/material.dart';

import '../theme/application_accent_colors.dart';

/// Decorative corner shared by pages and modal sheets.
class ApplicationCornerAccent extends StatelessWidget {
  const ApplicationCornerAccent({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = ApplicationAccentColors.glow(brightness);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(
                alpha: brightness == Brightness.dark ? .28 : .55,
              ),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

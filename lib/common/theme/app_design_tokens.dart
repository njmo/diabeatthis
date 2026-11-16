import 'package:flutter/material.dart';

import '../nutrition/macro_colors.dart';

/// Centralized design tokens for consistent spacing, radii, colors and metrics.
abstract final class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double button = 16.0;
  static const double card = 20.0;
  static const double sheet = 28.0;
  static const double pill = 999.0;

  static const BorderRadius buttonBorderRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetBorderRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius pillBorderRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract final class AppSizes {
  static const double buttonHeight = 52.0;
  static const double iconSmall = 18.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 28.0;
  static const double badgeSize = 42.0;
}

abstract final class AppColors {
  // Macros
  static const Color carbs = MacroColors.carbs;
  static const Color protein = MacroColors.protein;
  static const Color fat = MacroColors.fat;
  static const Color fiber = MacroColors.fiber;

  // Semantic diabetes metrics
  static const Color iobLight = Color(0xFF08799E);
  static const Color iobDark = Color(0xFF80D8F7);
  static Color iob(Brightness brightness) =>
      brightness == Brightness.dark ? iobDark : iobLight;

  static const Color cobLight = Color(0xFFD99B26);
  static const Color cobDark = Color(0xFFF3C96A);
  static Color cob(Brightness brightness) =>
      brightness == Brightness.dark ? cobDark : cobLight;

  // Quick action accents
  static const Color hypo = Color(0xFFF28C38);
  static const Color quickSnack = Color(0xFFE58F45);
  static const Color activity = Color(0xFF62CBB2);
  static const Color stress = Color(0xFFB9A0DE);
  static const Color meal = Color(0xFF0E6E56);
  static const Color photoMeal = Color(0xFF0288D1);
}

abstract final class AppShadows {
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get floating => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

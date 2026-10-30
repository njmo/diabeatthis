import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData applicationThemeData({Brightness brightness = Brightness.light}) {
  final defaults = ThemeData(brightness: brightness, useMaterial3: true);
  final base = defaults.copyWith(
    textTheme: GoogleFonts.nunitoSansTextTheme(defaults.textTheme),
  );

  final isDark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xFF096785),
    brightness: brightness,
  );
  final colors = seeded.copyWith(
    surface: isDark ? const Color(0xFF111B21) : const Color(0xFFF3F6F8),
    surfaceContainerLow: isDark
        ? const Color(0xFF111B21)
        : const Color(0xFFF3F6F8),
    surfaceContainerLowest: isDark ? const Color(0xFF1A272E) : Colors.white,
  );
  return base.copyWith(
    colorScheme: colors,
    primaryColor: colors.primary,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    scaffoldBackgroundColor: colors.surfaceContainerLow,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: colors.surfaceContainerLow,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.surfaceContainerHighest,
      selectedColor: colors.primaryContainer,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    expansionTileTheme: base.expansionTileTheme.copyWith(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: colors.primary,
      collapsedIconColor: colors.onSurfaceVariant,
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: colors.outlineVariant.withValues(alpha: 0.45),
    ),
  );
}

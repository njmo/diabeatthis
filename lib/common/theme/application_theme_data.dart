import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'application_theme.dart';

ThemeData applicationThemeData(
  ApplicationTheme appearance, {
  Brightness brightness = Brightness.light,
}) {
  final defaults = ThemeData(brightness: brightness, useMaterial3: true);
  final base = defaults.copyWith(
    textTheme: GoogleFonts.nunitoSansTextTheme(defaults.textTheme),
  );
  if (appearance == ApplicationTheme.classic) return base;

  final isDark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B7455),
        brightness: brightness,
      ).copyWith(
        surface: isDark ? const Color(0xFF191713) : const Color(0xFFF7F5EF),
        surfaceContainerLow: isDark
            ? const Color(0xFF191713)
            : const Color(0xFFF7F5EF),
        surfaceContainerLowest: isDark
            ? const Color(0xFF211E19)
            : const Color(0xFFFFFDF8),
        primaryContainer: isDark
            ? const Color(0xFF443A2C)
            : const Color(0xFFEEE4D2),
        onPrimaryContainer: isDark
            ? const Color(0xFFF1E5D0)
            : const Color(0xFF3E3528),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

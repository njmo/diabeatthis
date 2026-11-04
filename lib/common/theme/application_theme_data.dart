import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData applicationThemeData({
  Brightness brightness = Brightness.light,
  TextTheme? textTheme,
}) {
  final defaults = ThemeData(brightness: brightness, useMaterial3: true);
  final base = defaults.copyWith(
    textTheme: textTheme ?? GoogleFonts.nunitoSansTextTheme(defaults.textTheme),
  );

  final isDark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xFF096785),
    brightness: brightness,
  );
  final colors = seeded.copyWith(
    surface: isDark ? const Color(0xFF111E25) : const Color(0xFFFAF8F3),
    surfaceContainerLow: isDark
        ? const Color(0xFF111E25)
        : const Color(0xFFFAF8F3),
    surfaceContainerLowest: isDark
        ? const Color(0xFF1A2930)
        : const Color(0xFFFFFEFC),
    surfaceContainerHigh: isDark
        ? const Color(0xFF233139)
        : const Color(0xFFF5F2ED),
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
    scaffoldBackgroundColor: Colors.transparent,
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
      backgroundColor: Colors.transparent,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.surfaceContainerLow,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.25)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colors.primary, width: 3),
        borderRadius: BorderRadius.circular(3),
      ),
      dividerColor: colors.outlineVariant.withValues(alpha: .35),
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

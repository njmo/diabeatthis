import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_design_tokens.dart';

final applicationLightThemeProvider = Provider<ThemeData>(
  (ref) => applicationThemeData(),
);
final applicationDarkThemeProvider = Provider<ThemeData>(
  (ref) => applicationThemeData(brightness: Brightness.dark),
);

ThemeData applicationThemeData({
  Brightness brightness = Brightness.light,
  TextTheme? textTheme,
}) {
  final defaults = ThemeData(brightness: brightness, useMaterial3: true);
  final base = defaults.copyWith(
    textTheme: textTheme ?? GoogleFonts.interTextTheme(defaults.textTheme),
  );

  final isDark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00A3FF),
    brightness: brightness,
  );
  final colors = seeded.copyWith(
    primary: const Color(0xFF00A3FF),
    onPrimary: Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF00A3FF).withValues(alpha: 0.20)
        : const Color(0xFFE0F2FE),
    onPrimaryContainer:
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
    secondary: const Color(0xFF38BDF8),
    onSecondary: isDark ? const Color(0xFF0F172A) : Colors.white,
    secondaryContainer:
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    onSecondaryContainer:
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    surface: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF8F3),
    surfaceContainerLow:
        isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF8F3),
    surfaceContainer:
        isDark ? const Color(0xFF1E293B) : Colors.white,
    surfaceContainerLowest:
        isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFEFC),
    surfaceContainerHigh:
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    surfaceContainerHighest:
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    outline: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    outlineVariant: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    onSurface: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
    onSurfaceVariant:
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
  );
  return base.copyWith(
    colorScheme: colors,
    primaryColor: colors.primary,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00A3FF), width: 1.5),
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
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.sheetBorderRadius,
      ),
      showDragHandle: true,
      dragHandleColor: colors.outlineVariant.withValues(alpha: 0.5),
      dragHandleSize: const Size(36, 4),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSizes.buttonHeight),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppSizes.buttonHeight),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
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
      backgroundColor: isDark
          ? const Color(0xFF1E293B)
          : colors.surfaceContainerHighest,
      selectedColor: colors.primaryContainer,
      side: BorderSide(color: colors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

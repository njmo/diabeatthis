import 'package:diabeatthis/common/theme/app_design_tokens.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  group('AppDesignTokens', () {
    test('defines predictable and consistent spacing scale', () {
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
    });

    test('defines consistent radii scale', () {
      expect(AppRadius.xs, 4.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.button, 16.0);
      expect(AppRadius.card, 20.0);
      expect(AppRadius.sheet, 28.0);
      expect(AppRadius.pill, 999.0);
    });

    test('defines semantic diabetes and macro colors', () {
      expect(AppColors.iobLight, const Color(0xFF08799E));
      expect(AppColors.cobLight, const Color(0xFFD99B26));
      expect(AppColors.hypo, const Color(0xFFF28C38));
      expect(AppColors.activity, const Color(0xFF62CBB2));
      expect(AppColors.stress, const Color(0xFFB9A0DE));
      expect(AppColors.meal, const Color(0xFF0E6E56));
    });
  });

  group('ApplicationThemeData', () {
    test('configures global filled button theme with 52dp height and r16', () {
      final theme = applicationThemeData(textTheme: const TextTheme());
      final filledTheme = theme.filledButtonTheme.style;

      expect(filledTheme, isNotNull);
      expect(filledTheme?.minimumSize?.resolve({}), const Size(0, 52));
      expect(filledTheme?.elevation?.resolve({}), 0);

      final shape = filledTheme?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, AppRadius.buttonBorderRadius);
    });

    test('configures global outlined button theme with 52dp height and r16', () {
      final theme = applicationThemeData(textTheme: const TextTheme());
      final outlinedTheme = theme.outlinedButtonTheme.style;

      expect(outlinedTheme, isNotNull);
      expect(outlinedTheme?.minimumSize?.resolve({}), const Size(0, 52));
      expect(outlinedTheme?.elevation?.resolve({}), 0);

      final shape =
          outlinedTheme?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, AppRadius.buttonBorderRadius);
    });

    test('configures global bottom sheet theme with r28 top and drag handle', () {
      final theme = applicationThemeData(textTheme: const TextTheme());
      final sheetTheme = theme.bottomSheetTheme;

      expect(sheetTheme.showDragHandle, isTrue);
      expect(sheetTheme.shape, const RoundedRectangleBorder(
        borderRadius: AppRadius.sheetBorderRadius,
      ));
      expect(sheetTheme.clipBehavior, Clip.antiAlias);
    });

    test('configures global card theme without harsh border and with r20', () {
      final theme = applicationThemeData(textTheme: const TextTheme());
      final cardTheme = theme.cardTheme;

      expect(cardTheme.elevation, 0);
      expect(cardTheme.shape, const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
      ));
    });

    test('configures global dialog theme with r20', () {
      final theme = applicationThemeData(textTheme: const TextTheme());
      final dialogTheme = theme.dialogTheme;

      expect(dialogTheme.elevation, 6);
      expect(dialogTheme.shape, const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorderRadius,
      ));
    });
  });
}

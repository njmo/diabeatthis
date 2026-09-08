import 'package:diabeatthis/common/theme/application_theme_controller.dart';
import 'package:diabeatthis/common/theme/application_theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing and unknown modes follow the system', () async {
    for (final stored in [null, 'unknown']) {
      SharedPreferences.setMockInitialValues({
        if (stored != null) applicationThemeModeKey: stored,
      });
      final container = ProviderContainer();
      expect(
        await container.read(applicationThemeModeControllerProvider.future),
        ThemeMode.system,
      );
      container.dispose();
    }
  });

  test(
    'each mode survives restart without changing the selected palette',
    () async {
      SharedPreferences.setMockInitialValues({applicationThemeKey: 'cream'});
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        final container = ProviderContainer();
        await container.read(applicationThemeModeControllerProvider.future);
        await container
            .read(applicationThemeModeControllerProvider.notifier)
            .setMode(mode);
        container.dispose();
        final restored = ProviderContainer();
        expect(
          await restored.read(applicationThemeModeControllerProvider.future),
          mode,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            applicationThemeKey,
          ),
          'cream',
        );
        restored.dispose();
      }
    },
  );
}

import 'package:diabeatthis/common/theme/application_theme.dart';
import 'package:diabeatthis/common/theme/application_theme_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'missing or unknown preference preserves the classic appearance',
    () async {
      for (final stored in [null, 'unknown']) {
        SharedPreferences.setMockInitialValues({
          if (stored != null) applicationThemeKey: stored,
        });
        final container = ProviderContainer();
        expect(
          await container.read(applicationThemeControllerProvider.future),
          ApplicationTheme.classic,
        );
        container.dispose();
      }
    },
  );

  test(
    'saved selection survives a fresh provider container and can be reverted',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(applicationThemeControllerProvider.future);
      await first
          .read(applicationThemeControllerProvider.notifier)
          .setTheme(ApplicationTheme.cream);
      expect(
        first.read(applicationThemeControllerProvider).requireValue,
        ApplicationTheme.cream,
      );
      first.dispose();

      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      expect(
        await restored.read(applicationThemeControllerProvider.future),
        ApplicationTheme.cream,
      );
      await restored
          .read(applicationThemeControllerProvider.notifier)
          .setTheme(ApplicationTheme.classic);
      expect(
        (await SharedPreferences.getInstance()).getString(applicationThemeKey),
        'classic',
      );
    },
  );
}

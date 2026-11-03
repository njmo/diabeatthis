import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/application_language_storage_keys.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/controlled_preferences.dart';

void main() {
  tearDown(() => setLanguageStringsFromCode('pl'));
  for (final stored in [null, 'unknown', 'en', 'pl', 'system']) {
    test(
      'stored language has deterministic fallback; stored=$stored',
      () async {
        final prefs = ControlledPreferences({
          if (stored != null) applicationLanguageCodeKey: stored,
        });
        final container = ProviderContainer(
          overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
        );
        addTearDown(container.dispose);
        final language = await container.read(
          applicationLanguageControllerProvider.future,
        );
        expect(
          language.code,
          stored == null || stored == 'unknown' ? 'pl' : stored,
        );
        expect(prefs.writes, isEmpty);
      },
    );
  }
  test(
    'failed language save restores the previous selection; retry persists',
    () async {
      final prefs = ControlledPreferences({applicationLanguageCodeKey: 'pl'});
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(container.dispose);
      await container.read(applicationLanguageControllerProvider.future);
      final controller = container.read(
        applicationLanguageControllerProvider.notifier,
      );
      prefs.acceptWrites = false;
      await expectLater(
        controller.setLanguage(applicationLanguageByCode('en')),
        throwsStateError,
      );
      expect(
        container.read(applicationLanguageControllerProvider).value!.code,
        'pl',
      );
      expect(prefs.values[applicationLanguageCodeKey], 'pl');
      prefs.acceptWrites = true;
      await controller.setLanguage(applicationLanguageByCode('en'));
      expect(
        await container
            .read(applicationLanguageControllerProvider.future)
            .then((value) => value.code),
        'en',
      );
      expect(prefs.values[applicationLanguageCodeKey], 'en');
    },
  );
}

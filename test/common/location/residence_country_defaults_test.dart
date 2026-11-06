import 'dart:ui';

import 'package:diabeatthis/common/location/residence_country_provider.dart';
import 'package:diabeatthis/common/location/resolve_residence_country_use_case.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'explicit country wins over device region and bare language does not imply a country',
    () {
      const resolve = ResolveResidenceCountryUseCase();
      expect(
        resolve(override: ' Poland ', locales: [const Locale('en', 'GB')]),
        'Poland',
      );
      expect(resolve(locales: [const Locale('pl')]), isNull);
      expect(resolve(locales: [const Locale('en', 'GB')]), 'GB');
      expect(
        resolve(locales: [const Locale('es', '419'), const Locale('pl', 'PL')]),
        'PL',
      );
    },
  );
  test(
    'automatic country uses locale without persisting it; manual override and reset work',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          deviceCountryLocalesProvider.overrideWithValue([
            const Locale('en', 'GB'),
          ]),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(residenceCountryProvider.future), 'GB');
      expect(prefs.getKeys(), isEmpty);
      await prefs.setString(residenceCountryKey, 'Poland');
      container.invalidate(residenceCountryOverrideProvider);
      expect(await container.read(residenceCountryProvider.future), 'Poland');
      await prefs.remove(residenceCountryKey);
      container.invalidate(residenceCountryOverrideProvider);
      expect(await container.read(residenceCountryProvider.future), 'GB');
    },
  );
}

import 'dart:async';

import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/features/settings/presentation/screens/settings_page.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/temp_target_settings_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'upload controls remain available with AAPS and local read sources',
    (tester) async {
      tester.view.physicalSize = const Size(2600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        dataSourceBgSourceKey: 'aaps',
        dataSourceTreatmentsSourceKey: 'aaps',
        dataSourcePumpStatusSourceKey: 'aaps',
        dataSourceHistorySourceKey: 'local',
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((_) async => prefs),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (_) async => const DataSourceOptionAvailability(
                aapsInstalled: true,
                xdripInstalled: false,
              ),
            ),
          ],
          child: localizedMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byType(TempTargetSettingsSwitch);
      await tester.ensureVisible(toggle);
      expect(toggle, findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Token Nightscout'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.descendant(
                of: toggle,
                matching: find.byType(SwitchListTile),
              ),
            )
            .onChanged,
        isNull,
      );
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validation finishing after closing settings does not update disposed hooks',
    (tester) async {
      tester.view.physicalSize = const Size(2600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.com',
        nightscoutTokenKey: 'existing-token',
        nightscoutTempTargetsEnabledKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final response = Completer<http.Response>();
      final requested = Completer<void>();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((_) async => prefs),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (_) async => const DataSourceOptionAvailability.none(),
            ),
            nightscoutTokenValidatorProvider.overrideWithValue(
              NightscoutTokenValidator(
                client: MockClient((_) {
                  requested.complete();
                  return response.future;
                }),
              ),
            ),
          ],
          child: localizedMaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, showSettings, _) => showSettings
                  ? const SettingsPage()
                  : const Scaffold(body: Text('Settings closed')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byType(TempTargetSettingsSwitch);
      await tester.ensureVisible(toggle);
      await tester.tap(
        find.descendant(of: toggle, matching: find.byType(SwitchListTile)),
      );
      await tester.pumpAndSettle();
      final save = find.text('Zapisz i przejdź dalej');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      await requested.future;
      visible.value = false;
      await tester.pump();
      response.complete(http.Response('', 401));
      await tester.pumpAndSettle();
      expect(find.text('Settings closed'), findsOneWidget);
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

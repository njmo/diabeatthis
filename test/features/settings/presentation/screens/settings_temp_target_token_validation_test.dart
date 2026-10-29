import 'dart:convert';

import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
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
  for (final invalidIdentity in [true, false]) {
    testWidgets(
      'saving enabled targets with ${invalidIdentity ? 'an invalid' : 'a read-only'} token leaves preferences unchanged',
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
        var requests = 0;
        final validator = NightscoutTokenValidator(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            requests++;
            if (invalidIdentity) return http.Response('', 401);
            return http.Response(
              jsonEncode(
                requests == 1
                    ? {'token': 'jwt'}
                    : {
                        'result': {
                          'apiPermissions': {'treatments': 'r'},
                        },
                      },
              ),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWith((_) async => prefs),
              dataSourceOptionAvailabilityProvider.overrideWith(
                (_) async => const DataSourceOptionAvailability.none(),
              ),
              nightscoutTokenValidatorProvider.overrideWithValue(validator),
            ],
            child: localizedMaterialApp(home: const SettingsPage()),
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
        await tester.pumpAndSettle();
        expect(requests, invalidIdentity ? 1 : 2);
        expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
        expect(prefs.getString(nightscoutTokenKey), 'existing-token');
        expect(
          find.textContaining(
            invalidIdentity
                ? 'Nightscout odrzucił token'
                : 'Token nie ma prawa odczytu',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'clearing the token while targets are enabled prevents saving before any network request',
    (tester) async {
      tester.view.physicalSize = const Size(2600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.com',
        nightscoutTokenKey: 'existing-token',
        nightscoutTempTargetsEnabledKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      var requests = 0;
      final validator = NightscoutTokenValidator(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((_) async => prefs),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (_) async => const DataSourceOptionAvailability.none(),
            ),
            nightscoutTokenValidatorProvider.overrideWithValue(validator),
          ],
          child: localizedMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final token = find.widgetWithText(TextFormField, 'Token Nightscout');
      await tester.ensureVisible(token);
      await tester.enterText(token, '   ');
      final save = find.text('Zapisz i przejdź dalej');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(prefs.getString(nightscoutTokenKey), 'existing-token');
      expect(
        find.textContaining('Przed włączeniem opcji uzupełnij token'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

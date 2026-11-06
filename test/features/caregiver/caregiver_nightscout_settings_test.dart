import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/app/providers/app_foreground_bridge_provider.dart';
import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import 'package:diabeatthis/features/settings/application/save_nightscout_settings_use_case.dart';
import 'package:diabeatthis/features/settings/data/models/nightscout_settings_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/application/setup_nightscout_validation_test.dart'
    show SetupTokenValidator;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final writesEnabled in [false, true]) {
    test(
      'caregiver connection changes do not invoke foreground and reject uploads: write=$writesEnabled',
      () async {
        SharedPreferences.setMockInitialValues({
          applicationDeviceModeKey: 'caregiver',
          nightscoutUrlKey: 'https://old.test',
          nightscoutTokenKey: 'read-token',
        });
        final prefs = await SharedPreferences.getInstance();
        final validator = SetupTokenValidator();
        var foregroundReads = 0;
        var connectionChecks = 0;
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            appForegroundBridgeProvider.overrideWith((ref) {
              foregroundReads++;
              throw StateError('Caregiver settings cannot start foreground');
            }),
            appEventRouterProvider.overrideWith(
              (ref) => throw StateError(
                'Caregiver settings cannot send patient commands',
              ),
            ),
            nightscoutTokenValidatorProvider.overrideWithValue(validator),
            nightscoutConnectionCheckProvider.overrideWithValue(({
              required String url,
              required String token,
            }) async {
              connectionChecks++;
            }),
          ],
        );
        addTearDown(container.dispose);
        final operation = container.read(saveNightscoutSettingsUseCaseProvider)(
          NightscoutSettingsDraft(
            url: 'https://new.test',
            token: 'read-token',
            tempTargetsEnabled: writesEnabled,
            childName: 'Parent',
            dataSourceConfig: const DataSourceConfig.defaults(),
          ),
        );
        if (writesEnabled) {
          await expectLater(operation, throwsStateError);
          expect(prefs.getString(nightscoutUrlKey), 'https://old.test');
          expect(connectionChecks, 0);
        } else {
          await operation;
          expect(prefs.getString(nightscoutUrlKey), 'https://new.test');
          expect(connectionChecks, 1);
          expect(validator.requests, [false]);
        }
        expect(foregroundReads, 0);
      },
    );
  }
}

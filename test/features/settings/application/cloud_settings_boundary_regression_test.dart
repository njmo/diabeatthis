import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import 'package:diabeatthis/features/settings/application/save_nightscout_settings_use_case.dart';
import 'package:diabeatthis/features/settings/data/models/nightscout_settings_draft.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/regression/scripted_read.dart';
import 'save_nightscout_settings_use_case_test.dart'
    show ControlledNightscoutTokenValidator, RecordingSettingsEventRouter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final unavailable in [false, true]) {
    test(
      'cloud settings validate the exact endpoint before saving; unavailable=$unavailable',
      () async {
        SharedPreferences.setMockInitialValues({
          nightscoutUrlKey: 'https://old.test',
          nightscoutTokenKey: 'old-token',
          childNameKey: 'Old',
        });
        final prefs = await SharedPreferences.getInstance();
        final validator = ControlledNightscoutTokenValidator();
        validator.result.complete();
        final checks = ScriptedRead<void>('Nightscout connection', [
          (
            arguments: ['https://new.test', 'new-token'],
            respond: () {
              if (unavailable) throw StateError('Mocked Nightscout outage');
            },
          ),
        ]);
        final router = RecordingSettingsEventRouter();
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            nightscoutTokenValidatorProvider.overrideWithValue(validator),
            nightscoutConnectionCheckProvider.overrideWithValue(
              ({required String url, required String token}) =>
                  checks([url, token]),
            ),
            monitorServiceEnabledProvider.overrideWith((ref) => false),
            appEventRouterProvider.overrideWithValue(router),
          ],
        );
        addTearDown(container.dispose);
        final result = container.read(saveNightscoutSettingsUseCaseProvider)(
          const NightscoutSettingsDraft(
            url: ' https://new.test ',
            token: ' new-token ',
            childName: ' New ',
            tempTargetsEnabled: false,
            dataSourceConfig: DataSourceConfig.defaults(),
          ),
        );
        if (unavailable) {
          await expectLater(result, throwsStateError);
          expect(prefs.getString(nightscoutUrlKey), 'https://old.test');
          expect(prefs.getString(nightscoutTokenKey), 'old-token');
          expect(prefs.getString(childNameKey), 'Old');
          expect(router.events, isEmpty);
        } else {
          await result;
          expect(prefs.getString(nightscoutUrlKey), 'https://new.test');
          expect(prefs.getString(nightscoutTokenKey), 'new-token');
          expect(prefs.getString(childNameKey), 'New');
          expect(router.events, hasLength(1));
        }
        expect(validator.calls, 1);
        checks.verifyComplete();
      },
    );
  }
}

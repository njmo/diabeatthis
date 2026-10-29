import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/features/settings/application/save_nightscout_settings_use_case.dart';
import 'package:diabeatthis/features/settings/data/models/nightscout_settings_draft.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'save_nightscout_settings_use_case_test.dart';

void main() {
  late SharedPreferences prefs;
  late UnavailableNightscoutTokenValidator validator;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'verified-token',
      nightscoutTempTargetsEnabledKey: true,
      childNameKey: 'Before',
    });
    prefs = await SharedPreferences.getInstance();
    validator = UnavailableNightscoutTokenValidator();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((_) async => prefs),
        nightscoutTokenValidatorProvider.overrideWithValue(validator),
        monitorServiceEnabledProvider.overrideWith((_) => false),
        appEventRouterProvider.overrideWithValue(
          RecordingSettingsEventRouter(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> save({
    String url = 'https://example.com',
    String token = 'verified-token',
    bool enabled = true,
  }) => container.read(saveNightscoutSettingsUseCaseProvider)(
    NightscoutSettingsDraft(
      url: url,
      token: token,
      tempTargetsEnabled: enabled,
      childName: 'After',
      dataSourceConfig: localSources,
    ),
  );

  test(
    'a local name edit saves offline with unchanged upload credentials',
    () async {
      await save();
      expect(validator.calls, 0);
      expect(prefs.getString(childNameKey), 'After');
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isTrue);
    },
  );

  test('disabling uploads needs no remote validation', () async {
    await save(enabled: false);
    expect(validator.calls, 0);
    expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
  });

  test(
    'enabling uploads still verifies the existing token before saving',
    () async {
      await prefs.setBool(nightscoutTempTargetsEnabledKey, false);
      await expectLater(
        save(),
        throwsA(isA<NightscoutTokenValidationException>()),
      );
      expect(validator.calls, 1);
      expect(validator.requireTreatmentWrite, isTrue);
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
      expect(prefs.getString(childNameKey), 'Before');
    },
  );

  for (final changedField in ['url', 'token']) {
    test(
      'changing $changedField still verifies write access before saving',
      () async {
        await expectLater(
          save(
            url: changedField == 'url'
                ? 'https://changed.example.com'
                : 'https://example.com',
            token: changedField == 'token' ? 'changed-token' : 'verified-token',
          ),
          throwsA(isA<NightscoutTokenValidationException>()),
        );
        expect(validator.calls, 1);
        expect(validator.requireTreatmentWrite, isTrue);
        expect(prefs.getString(nightscoutUrlKey), 'https://example.com');
        expect(prefs.getString(nightscoutTokenKey), 'verified-token');
        expect(prefs.getString(childNameKey), 'Before');
      },
    );
  }

  test(
    'an enabled configuration cannot preserve a missing token through local edits',
    () async {
      await prefs.setString(nightscoutTokenKey, '');
      await expectLater(
        save(token: ''),
        throwsA(
          isA<NightscoutTokenValidationException>().having(
            (error) => error.issue,
            'issue',
            NightscoutTokenIssue.required,
          ),
        ),
      );
      expect(validator.calls, 0);
      expect(prefs.getString(childNameKey), 'Before');
    },
  );
}

class UnavailableNightscoutTokenValidator extends NightscoutTokenValidator {
  var calls = 0;
  bool? requireTreatmentWrite;

  @override
  Future<void> validate({
    required String url,
    required String token,
    bool requireTreatmentWrite = true,
  }) async {
    calls++;
    this.requireTreatmentWrite = requireTreatmentWrite;
    throw const NightscoutTokenValidationException(
      NightscoutTokenIssue.unavailable,
    );
  }
}

import 'package:diabeatthis/app/event/app/app_event_router.dart';
import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/common/events/data/app/execute_command_event.dart';
import 'package:diabeatthis/common/events/data/app_event_data.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/features/settings/application/save_nightscout_settings_use_case.dart';
import 'package:diabeatthis/features/settings/data/models/nightscout_settings_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const localConfig = DataSourceConfig(
  bgSource: BgSource.aaps,
  treatmentsSource: TreatmentsSource.aaps,
  pumpStatusSource: PumpStatusSource.aaps,
  historySource: HistorySource.local,
  mirrorToLocal: false,
);

void main() {
  test(
    'enabling only low treatment uploads validates write access and syncs the setting',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.test',
        nightscoutTokenKey: 'token',
      });
      final prefs = await SharedPreferences.getInstance();
      final validator = UploadSettingsValidator();
      final router = UploadSettingsRouter();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          nightscoutTokenValidatorProvider.overrideWithValue(validator),
          appEventRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);
      await container.read(saveNightscoutSettingsUseCaseProvider)(
        const NightscoutSettingsDraft(
          url: 'https://example.test',
          token: 'token',
          tempTargetsEnabled: false,
          lowTreatmentsEnabled: true,
          childName: '',
          dataSourceConfig: localConfig,
        ),
      );
      expect(validator.requiredWrite, isTrue);
      expect(prefs.getBool(nightscoutLowTreatmentsEnabledKey), isTrue);
      expect(
        router.events.whereType<ExecuteCommandEventSyncSettings>().single.data,
        {nightscoutLowTreatmentsEnabledKey: 'true'},
      );
    },
  );

  test(
    'missing token prevents enabling uploads without persisting changes',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.test',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWith((_) async => prefs)],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(saveNightscoutSettingsUseCaseProvider)(
          const NightscoutSettingsDraft(
            url: 'https://example.test',
            token: '',
            tempTargetsEnabled: false,
            lowTreatmentsEnabled: true,
            childName: '',
            dataSourceConfig: localConfig,
          ),
        ),
        throwsA(isA<NightscoutTokenValidationException>()),
      );
      expect(prefs.getBool(nightscoutLowTreatmentsEnabledKey), isNull);
    },
  );

  test(
    'every URL change rotates delivery revision, including a return to the original URL',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://original.test',
        nightscoutDeliveryRevisionKey: 'old',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          appEventRouterProvider.overrideWithValue(UploadSettingsRouter()),
        ],
      );
      addTearDown(container.dispose);
      Future<void> save(String url) =>
          container.read(saveNightscoutSettingsUseCaseProvider)(
            NightscoutSettingsDraft(
              url: url,
              token: '',
              tempTargetsEnabled: false,
              childName: '',
              dataSourceConfig: localConfig,
            ),
          );
      await save('https://new.test');
      final revision = prefs.getString(nightscoutDeliveryRevisionKey);
      expect(revision, isNot('old'));
      await save('https://original.test');
      expect(prefs.getString(nightscoutDeliveryRevisionKey), isNot(revision));
    },
  );
}

class UploadSettingsValidator extends NightscoutTokenValidator {
  bool? requiredWrite;
  @override
  Future<void> validate({
    required String url,
    required String token,
    bool requireTreatmentWrite = true,
  }) async {
    requiredWrite = requireTreatmentWrite;
  }
}

class UploadSettingsRouter extends AppEventRouter {
  final events = <AppEventData>[];
  @override
  void send(AppEventData payload) => events.add(payload);
}

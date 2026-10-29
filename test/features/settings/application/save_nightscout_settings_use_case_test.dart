import 'dart:async';

import 'package:diabeatthis/app/event/app/app_event_router.dart';
import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/common/events/data/app/execute_command_event.dart';
import 'package:diabeatthis/common/events/data/app_event_data.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:diabeatthis/features/settings/application/save_nightscout_settings_use_case.dart';
import 'package:diabeatthis/features/settings/data/models/nightscout_settings_draft.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:diabeatthis/features/settings/presentation/controllers/nightscout_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const localSources = DataSourceConfig(
  bgSource: BgSource.aaps,
  treatmentsSource: TreatmentsSource.aaps,
  pumpStatusSource: PumpStatusSource.aaps,
  historySource: HistorySource.local,
  mirrorToLocal: false,
);

void main() {
  test('failed token validation preserves the complete saved draft', () async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://previous.example.com',
      nightscoutTokenKey: 'previous-token',
      nightscoutTempTargetsEnabledKey: false,
      childNameKey: 'Previous name',
    });
    final prefs = await SharedPreferences.getInstance();
    final validator = ControlledNightscoutTokenValidator();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((_) async => prefs),
        nightscoutTokenValidatorProvider.overrideWithValue(validator),
      ],
    );
    addTearDown(container.dispose);
    final save = container.read(saveNightscoutSettingsUseCaseProvider)(
      const NightscoutSettingsDraft(
        url: 'https://new.example.com',
        token: 'new-token',
        tempTargetsEnabled: true,
        childName: 'New name',
        dataSourceConfig: localSources,
      ),
    );
    final expectation = expectLater(
      save,
      throwsA(isA<NightscoutTokenValidationException>()),
    );
    await validator.started.future;
    validator.result.completeError(
      const NightscoutTokenValidationException(
        NightscoutTokenIssue.treatmentAccess,
      ),
    );
    await expectation;
    expect(prefs.getString(nightscoutUrlKey), 'https://previous.example.com');
    expect(prefs.getString(nightscoutTokenKey), 'previous-token');
    expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
    expect(prefs.getString(childNameKey), 'Previous name');
  });

  test('local read sources can save verified upload credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final validator = ControlledNightscoutTokenValidator();
    final router = RecordingSettingsEventRouter();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((_) async => prefs),
        nightscoutTokenValidatorProvider.overrideWithValue(validator),
        monitorServiceEnabledProvider.overrideWith((_) => false),
        appEventRouterProvider.overrideWithValue(router),
      ],
    );
    addTearDown(container.dispose);
    final save = container.read(saveNightscoutSettingsUseCaseProvider)(
      const NightscoutSettingsDraft(
        url: ' https://uploads.example.com ',
        token: ' upload-token ',
        tempTargetsEnabled: true,
        childName: ' Child ',
        dataSourceConfig: localSources,
      ),
    );
    await validator.started.future;
    expect(validator.requireTreatmentWrite, isTrue);
    validator.result.complete();
    await save;
    expect(prefs.getString(nightscoutUrlKey), 'https://uploads.example.com');
    expect(prefs.getString(nightscoutTokenKey), 'upload-token');
    expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isTrue);
    expect(prefs.getString(childNameKey), 'Child');
    expect(
      router.events.whereType<ExecuteCommandEventSyncData>(),
      hasLength(1),
    );
  });

  test(
    'local-only settings need no Nightscout URL when uploads are disabled',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutTempTargetsEnabledKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final validator = ControlledNightscoutTokenValidator();
      final router = RecordingSettingsEventRouter();
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
          url: '',
          token: '',
          tempTargetsEnabled: false,
          childName: 'Child',
          dataSourceConfig: localSources,
        ),
      );
      expect(validator.calls, 0);
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
      expect(prefs.getString(childNameKey), 'Child');
      expect(router.events, [
        const ExecuteCommandEvent.syncSettings(
          data: {nightscoutTempTargetsEnabledKey: 'false'},
        ),
      ]);
    },
  );

  test(
    'leaving the screen does not cancel an in-flight verified save or duplicate it',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.com',
        nightscoutTokenKey: 'existing-token',
        nightscoutTempTargetsEnabledKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final validator = ControlledNightscoutTokenValidator();
      final router = RecordingSettingsEventRouter();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          nightscoutTokenValidatorProvider.overrideWithValue(validator),
          appEventRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        nightscoutSettingsControllerProvider,
        (_, _) {},
      );
      final controller = container.read(
        nightscoutSettingsControllerProvider.notifier,
      );
      const draft = NightscoutSettingsDraft(
        url: 'https://example.com',
        token: 'existing-token',
        tempTargetsEnabled: true,
        childName: '',
        dataSourceConfig: localSources,
      );
      final save = controller.save(draft);
      await validator.started.future;
      expect(await controller.save(draft), isFalse);
      subscription.close();
      await container.pump();
      validator.result.complete();
      expect(await save, isTrue);
      expect(validator.calls, 1);
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isTrue);
      expect(
        router.events.whereType<ExecuteCommandEventSyncSettings>(),
        hasLength(1),
      );
      await container.pump();
    },
  );

  test(
    'disposing the application during validation avoids persistence and disposed provider access',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.com',
        nightscoutTokenKey: 'existing-token',
        nightscoutTempTargetsEnabledKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final validator = ControlledNightscoutTokenValidator();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          nightscoutTokenValidatorProvider.overrideWithValue(validator),
        ],
      );
      container.listen(nightscoutSettingsControllerProvider, (_, _) {});
      final save = container
          .read(nightscoutSettingsControllerProvider.notifier)
          .save(
            const NightscoutSettingsDraft(
              url: 'https://example.com',
              token: 'existing-token',
              tempTargetsEnabled: true,
              childName: '',
              dataSourceConfig: localSources,
            ),
          );
      await validator.started.future;
      container.dispose();
      validator.result.complete();
      await expectLater(save, completes);
      expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
    },
  );
}

class ControlledNightscoutTokenValidator extends NightscoutTokenValidator {
  final started = Completer<void>();
  final result = Completer<void>();
  var calls = 0;
  bool? requireTreatmentWrite;

  @override
  Future<void> validate({
    required String url,
    required String token,
    bool requireTreatmentWrite = true,
  }) {
    calls++;
    this.requireTreatmentWrite = requireTreatmentWrite;
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class RecordingSettingsEventRouter extends AppEventRouter {
  final events = <AppEventData>[];

  @override
  void send(AppEventData payload) => events.add(payload);
}

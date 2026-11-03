import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/application_language_storage_keys.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_activation_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data_sources/receiver/data_receiver_activation_controller_test.dart'
    show DataReceiverCall, RecordingDataReceiverController;
import '../../../helpers/regression/scripted_read.dart';
import 'save_nightscout_settings_use_case_test.dart'
    show RecordingSettingsEventRouter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const local = DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  );
  test(
    'local setup saves exact settings, activates configured receiver and publishes sync',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final xdrip = RecordingDataReceiverController();
      final aaps = RecordingDataReceiverController();
      final router = RecordingSettingsEventRouter();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          dataSourceOptionAvailabilityProvider.overrideWith(
            (ref) async => const DataSourceOptionAvailability(
              aapsInstalled: true,
              xdripInstalled: true,
            ),
          ),
          dataReceiverActivationControllerProvider.overrideWithValue(
            DataReceiverActivationController(
              xdripReceiverController: xdrip,
              aapsReceiverController: aaps,
            ),
          ),
          monitorServiceEnabledProvider.overrideWith((ref) => false),
          appEventRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);
      await container.read(applyInitialConfigurationUseCaseProvider)(
        config: local,
        nightscoutUrl: '',
        nightscoutToken: '',
        childName: ' Child ',
        language: applicationLanguageByCode('en'),
      );
      expect(prefs.getString(childNameKey), 'Child');
      expect(prefs.getString(applicationLanguageCodeKey), 'en');
      expect(prefs.getBool(initialConfigurationDoneKey), true);
      expect(prefs.getString(dataSourceBgSourceKey), 'aaps');
      expect(prefs.getString(dataSourceHistorySourceKey), 'local');
      expect(aaps.calls, [DataReceiverCall.enabled]);
      expect(xdrip.calls, isEmpty);
      expect(router.events, hasLength(2));
    },
  );

  test(
    'unavailable source rejects configuration before any storage or activation',
    () async {
      var reads = 0;
      final container = ProviderContainer(
        overrides: [
          dataSourceOptionAvailabilityProvider.overrideWith(
            (ref) async => const DataSourceOptionAvailability.none(),
          ),
          sharedPrefsProvider.overrideWith((ref) async {
            reads++;
            throw StateError('Unexpected preferences read');
          }),
          dataReceiverActivationControllerProvider.overrideWith(
            (ref) => throw StateError('Unexpected receiver activation'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(applyInitialConfigurationUseCaseProvider)(
          config: local,
          nightscoutUrl: '',
          nightscoutToken: '',
          childName: 'Child',
          language: applicationLanguageByCode('pl'),
        ),
        throwsA(isA<DataSourceConfigUnavailableException>()),
      );
      expect(reads, 0);
    },
  );
  for (final failure in [false, true]) {
    test(
      'cloud setup checks connectivity before persistence; failure=$failure',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final checks = ScriptedRead<void>('initial Nightscout check', [
          (
            arguments: ['https://example.test', 'token'],
            respond: () {
              if (failure) throw StateError('Scripted connection failure');
            },
          ),
        ]);
        final router = RecordingSettingsEventRouter();
        final xdrip = RecordingDataReceiverController();
        final aaps = RecordingDataReceiverController();
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (ref) async => const DataSourceOptionAvailability.none(),
            ),
            nightscoutConnectionCheckProvider.overrideWithValue(
              ({required String url, required String token}) =>
                  checks([url, token]),
            ),
            dataReceiverActivationControllerProvider.overrideWithValue(
              DataReceiverActivationController(
                xdripReceiverController: xdrip,
                aapsReceiverController: aaps,
              ),
            ),
            monitorServiceEnabledProvider.overrideWith((ref) => false),
            appEventRouterProvider.overrideWithValue(router),
          ],
        );
        addTearDown(container.dispose);
        final operation =
            container.read(applyInitialConfigurationUseCaseProvider)(
              config: const DataSourceConfig.defaults(),
              nightscoutUrl: 'https://example.test',
              nightscoutToken: 'token',
              childName: 'Child',
              language: applicationLanguageByCode('pl'),
            );
        if (failure) {
          await expectLater(operation, throwsStateError);
          expect(prefs.getKeys(), isEmpty);
          expect(router.events, isEmpty);
        } else {
          await operation;
          expect(prefs.getString(nightscoutUrlKey), 'https://example.test');
          expect(prefs.getString(nightscoutTokenKey), 'token');
          expect(prefs.getBool(initialConfigurationDoneKey), true);
          expect(router.events, hasLength(2));
        }
        expect(xdrip.calls, isEmpty);
        expect(aaps.calls, isEmpty);
        checks.verifyComplete();
      },
    );
  }
}

import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/app/providers/app_foreground_bridge_provider.dart';
import 'package:diabeatthis/app/providers/foreground_task_state_provider.dart';
import 'package:diabeatthis/common/events/data/app/execute_command_event.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_connection_check_provider.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_activation_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data_sources/receiver/data_receiver_activation_controller_test.dart'
    show DataReceiverCall, RecordingDataReceiverController;
import '../../../helpers/regression/controlled_app_foreground_bridge.dart';
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
  late SharedPreferences prefs;
  late ControlledAppForegroundBridge bridge;
  late RecordingSettingsEventRouter router;
  late RecordingDataReceiverController aaps;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    bridge = ControlledAppForegroundBridge();
    router = RecordingSettingsEventRouter();
    aaps = RecordingDataReceiverController();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((ref) async => prefs),
        dataSourceOptionAvailabilityProvider.overrideWith(
          (ref) async => const DataSourceOptionAvailability(
            aapsInstalled: true,
            xdripInstalled: false,
          ),
        ),
        nightscoutConnectionCheckProvider.overrideWith(
          (ref) =>
              throw StateError('Local setup must not check cloud connectivity'),
        ),
        dataReceiverActivationControllerProvider.overrideWithValue(
          DataReceiverActivationController(
            xdripReceiverController: RecordingDataReceiverController(),
            aapsReceiverController: aaps,
          ),
        ),
        appForegroundBridgeProvider.overrideWithValue(bridge),
        appEventRouterProvider.overrideWithValue(router),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      applyInitialConfigurationUseCaseProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
  });

  Future<void> configure() =>
      container.read(applyInitialConfigurationUseCaseProvider)(
        config: local,
        nightscoutUrl: '',
        nightscoutToken: '',
        childName: 'Child',
        language: applicationLanguageByCode('en'),
      );

  test(
    'patient monitoring stays enabled by default for existing installations',
    () async {
      await prefs.setBool(initialConfigurationDoneKey, true);
      expect(container.read(monitorServiceEnabledProvider), isTrue);
    },
  );

  test(
    'offline local setup waits for patient service readiness before startup sync',
    () async {
      var completed = false;
      final operation = configure().then((_) => completed = true);
      await bridge.started.future;
      // Let service startup finish so assertions exercise the readiness wait.
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getBool(initialConfigurationDoneKey), isTrue);
      expect(aaps.calls, [DataReceiverCall.enabled]);
      expect(bridge.calls, ['isRunning', 'start']);
      expect(router.events, isEmpty);
      expect(completed, isFalse);

      container.read(foregroundTaskStateProvider.notifier).setAlive(true);
      await operation;

      expect(completed, isTrue);
      expect(router.events, [
        const ExecuteCommandEvent.syncSettings(
          data: {
            'data-source-bg-source': 'aaps',
            'data-source-treatments-source': 'aaps',
            'data-source-pump-status-source': 'aaps',
            'data-source-history-source': 'local',
            'data-source-mirror-to-local': 'false',
          },
        ),
        const ExecuteCommandEvent.syncData(
          data: ['glucose_list', 'device_status', 'temporary_target'],
        ),
      ]);
    },
  );

  test(
    'running patient service prevents a duplicate initial start and startup sync',
    () async {
      bridge.running = true;

      await expectLater(configure(), throwsStateError);

      expect(bridge.calls, ['isRunning']);
      expect(router.events, isEmpty);
    },
  );

  test(
    'failed patient service start does not publish premature startup sync',
    () async {
      final failure = StateError('Service unavailable');
      bridge.startError = failure;

      await expectLater(configure(), throwsA(same(failure)));

      expect(bridge.calls, ['isRunning', 'start']);
      expect(router.events, isEmpty);
      expect(container.read(foregroundTaskStateProvider).alive, isFalse);
    },
  );
}

import 'dart:async';

import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/common/family_sync/enable_initial_family_sharing.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_activation_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import 'package:diabeatthis/features/settings/presentation/controllers/initial_configuration_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data_sources/receiver/data_receiver_activation_controller_test.dart'
    show RecordingDataReceiverController;
import 'save_nightscout_settings_use_case_test.dart'
    show RecordingSettingsEventRouter;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'success',
    'configuration-failure',
    'activation-failure',
    'local-only',
  ]) {
    test(
      'real setup commits completion only after selected sharing: $scenario',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final entered = Completer<void>();
        final release = Completer<void>();
        var activations = 0;
        var sourceAvailable = scenario != 'configuration-failure';
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            dataSourceConfigProvider.overrideWith(
              (ref) async => const DataSourceConfig(
                bgSource: BgSource.aaps,
                treatmentsSource: TreatmentsSource.aaps,
                pumpStatusSource: PumpStatusSource.aaps,
                historySource: HistorySource.local,
                mirrorToLocal: false,
              ),
            ),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (ref) async => DataSourceOptionAvailability(
                aapsInstalled: sourceAvailable,
                xdripInstalled: true,
              ),
            ),
            dataReceiverActivationControllerProvider.overrideWithValue(
              DataReceiverActivationController(
                xdripReceiverController: RecordingDataReceiverController(),
                aapsReceiverController: RecordingDataReceiverController(),
              ),
            ),
            monitorServiceEnabledProvider.overrideWith((ref) => false),
            appEventRouterProvider.overrideWithValue(
              RecordingSettingsEventRouter(),
            ),
            enableInitialFamilySharingProvider.overrideWithValue(() async {
              activations++;
              expect(prefs.getBool(initialConfigurationDoneKey), isNot(true));
              if (scenario == 'activation-failure') {
                throw StateError('Account changed');
              }
              entered.complete();
              await release.future;
            }),
          ],
        );
        container.listen(initialConfigurationControllerProvider, (_, _) {});
        await container.read(initialConfigurationControllerProvider.future);
        final controller = container.read(
          initialConfigurationControllerProvider.notifier,
        );
        final operation = controller.submit(
          enableFamilySharing: scenario != 'local-only',
        );
        if (scenario == 'success') {
          await entered.future;
          expect(prefs.getBool(initialConfigurationDoneKey), isNot(true));
          release.complete();
        }
        expect(
          await operation,
          scenario == 'success' || scenario == 'local-only',
        );
        expect(
          activations,
          scenario == 'success' || scenario == 'activation-failure' ? 1 : 0,
        );
        if (scenario == 'activation-failure') {
          expect(prefs.getBool(initialConfigurationDoneKey), isNot(true));
        }
        if (scenario == 'configuration-failure') {
          sourceAvailable = true;
          container.invalidate(dataSourceOptionAvailabilityProvider);
          expect(await controller.submit(enableFamilySharing: false), isTrue);
          expect(activations, 0);
        }
        container.dispose();
      },
    );
  }
}

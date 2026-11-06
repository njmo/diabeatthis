import 'package:diabeatthis/app/lifecycle/stop_patient_runtime_provider.dart';
import 'package:diabeatthis/app/providers/app_foreground_bridge_provider.dart';
import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/auth/google_authentication_repository.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/monitor_service_enabled_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_connection_verification.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/receiver/data_receiver_activation_controller.dart';
import 'package:diabeatthis/core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import 'package:diabeatthis/features/settings/application/apply_caregiver_configuration_use_case.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data_sources/receiver/data_receiver_activation_controller_test.dart'
    show DataReceiverCall, RecordingDataReceiverController;

class CaregiverGoogleRepository implements GoogleAuthenticationRepository {
  CaregiverGoogleRepository(this.account);
  GoogleAccount? account;
  @override
  bool get isSupported => true;
  @override
  Stream<GoogleAccount?> watchAccount() => Stream.value(account);
  @override
  Future<GoogleAccount?> signIn() async => account;
  @override
  Future<void> signOut() async {
    account = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final signedIn in [false, true]) {
    test(
      'caregiver save requires Google and persists a read-only runtime: signedIn=$signedIn',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final aaps = RecordingDataReceiverController();
        final xdrip = RecordingDataReceiverController();
        var stops = 0;
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            googleAuthenticationRepositoryProvider.overrideWithValue(
              CaregiverGoogleRepository(
                signedIn
                    ? const GoogleAccount(uid: 'p', displayName: 'Parent Name')
                    : null,
              ),
            ),
            stopPatientRuntimeProvider.overrideWithValue(() async {
              stops++;
            }),
            appForegroundBridgeProvider.overrideWith(
              (ref) => throw StateError(
                'Caregiver save must not start a foreground runtime',
              ),
            ),
            dataReceiverActivationControllerProvider.overrideWithValue(
              DataReceiverActivationController(
                xdripReceiverController: xdrip,
                aapsReceiverController: aaps,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(nightscoutConnectionVerificationProvider)
            .remember(url: 'https://nightscout.test', token: 'read-token');
        final operation = container.read(applyCaregiverConfigurationProvider)(
          url: 'https://nightscout.test',
          token: 'read-token',
          userName: 'ignored local name',
          language: applicationLanguageByCode('en'),
        );
        if (!signedIn) {
          await expectLater(operation, throwsStateError);
          expect(prefs.getKeys(), isEmpty);
          expect(stops, 0);
        } else {
          await operation;
          expect(prefs.getString(applicationDeviceModeKey), 'caregiver');
          expect(prefs.getString(childNameKey), 'Parent Name');
          expect(prefs.getBool(initialConfigurationDoneKey), isTrue);
          expect(prefs.getBool(nightscoutTempTargetsEnabledKey), isFalse);
          expect(prefs.getBool(nightscoutLowTreatmentsEnabledKey), isFalse);
          expect(
            await container.read(applicationDeviceModeProvider.future),
            ApplicationDeviceMode.caregiver,
          );
          expect(container.read(monitorServiceEnabledProvider), isFalse);
          expect(aaps.calls, [DataReceiverCall.disabled]);
          expect(xdrip.calls, [DataReceiverCall.disabled]);
          expect(stops, 1);
        }
      },
    );
  }
}

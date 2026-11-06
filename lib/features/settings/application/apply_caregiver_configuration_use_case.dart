import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifecycle/stop_patient_runtime_provider.dart';
import '../../../common/app_mode/application_device_mode.dart';
import '../../../common/auth/google_authentication_providers.dart';
import '../../../common/l10n/application_language.dart';
import '../../../common/l10n/application_language_storage_keys.dart';
import '../../../core/data/provider/initial_configuration_provider.dart';
import '../../../core/data/provider/shared_prefs_provider.dart';
import '../../../core/data_sources/config/data_source_config.dart';
import '../../../core/data_sources/config/helpers/data_source_config_storer.dart';
import '../../../core/data_sources/nightscout/nightscout_connection_verification.dart';
import '../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../../../core/data_sources/receiver/providers/data_receiver_activation_controller_provider.dart';
import '../data/settings_storage_keys.dart';
import 'validate_setup_nightscout_use_case.dart';

final applyCaregiverConfigurationProvider = Provider(
  (ref) => ApplyCaregiverConfigurationUseCase(ref),
);

class ApplyCaregiverConfigurationUseCase {
  const ApplyCaregiverConfigurationUseCase(this.ref);
  final Ref ref;
  Future<void> call({
    required String url,
    required String token,
    required String userName,
    required ApplicationLanguage language,
  }) async {
    final account = await ref
        .read(googleAuthenticationRepositoryProvider)
        .watchAccount()
        .first
        .timeout(const Duration(seconds: 10));
    if (account == null) {
      throw StateError('A Google account is required for caregiver mode.');
    }
    final address = url.trim();
    final accessToken = token.trim();
    if (address.isEmpty) throw ArgumentError('Nightscout URL is required.');
    if (!ref
        .read(nightscoutConnectionVerificationProvider)
        .matches(url: address, token: accessToken)) {
      await ref.read(validateSetupNightscoutProvider)(
        address,
        accessToken,
        false,
      );
    }
    final currentAccount = await ref
        .read(googleAuthenticationRepositoryProvider)
        .watchAccount()
        .first
        .timeout(const Duration(seconds: 10));
    if (currentAccount?.uid != account.uid) {
      throw StateError('Google account changed during setup.');
    }
    await ref.read(stopPatientRuntimeProvider)();
    final prefs = await ref.read(sharedPrefsProvider.future);
    const cloud = DataSourceConfig.defaults();
    await ref.read(dataReceiverActivationControllerProvider).disableAll();
    await DataSourceConfigStorer(prefs).save(cloud);
    for (final result in await Future.wait([
      prefs.setString(nightscoutUrlKey, address),
      prefs.setString(nightscoutTokenKey, accessToken),
      prefs.setString(
        childNameKey,
        account.label.isEmpty ? userName.trim() : account.label,
      ),
      prefs.setString(applicationLanguageCodeKey, language.code),
      prefs.setBool(nightscoutTempTargetsEnabledKey, false),
      prefs.setBool(nightscoutLowTreatmentsEnabledKey, false),
    ])) {
      if (!result) throw StateError('Caregiver configuration was not saved.');
    }
    if (!await prefs.setString(
      applicationDeviceModeKey,
      ApplicationDeviceMode.caregiver.name,
    )) {
      throw StateError('Device mode was not saved.');
    }
    if (!await prefs.setBool(initialConfigurationDoneKey, true)) {
      throw StateError('Configuration completion was not saved.');
    }
    setLanguageStringsFromCode(language.code);
    if (!ref.mounted) return;
    ref.invalidate(sharedPrefsProvider);
    ref.invalidate(initialConfigurationDoneProvider);
    ref.invalidate(nightscoutUrlProvider);
    ref.invalidate(nightscoutTokenProvider);
  }
}

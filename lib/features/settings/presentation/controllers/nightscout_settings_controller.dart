import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/nightscout/nightscout_token_validator.dart';
import '../../../../core/logger/logger.dart';
import '../../application/save_nightscout_settings_use_case.dart';
import '../../data/models/nightscout_settings_draft.dart';
import '../../data/models/nightscout_settings_save_state.dart';

final nightscoutSettingsControllerProvider =
    NotifierProvider.autoDispose<
      NightscoutSettingsController,
      NightscoutSettingsSaveState
    >(NightscoutSettingsController.new);

class NightscoutSettingsController extends Notifier<NightscoutSettingsSaveState>
    with Logging {
  @override
  NightscoutSettingsSaveState build() => const NightscoutSettingsSaveState();

  void clearFailure() {
    if (!state.isSaving && state.failure != null) {
      state = const NightscoutSettingsSaveState();
    }
  }

  Future<bool> save(NightscoutSettingsDraft draft) async {
    if (state.isSaving) return false;

    // Keep the operation alive when the user leaves the settings page.
    final keepAlive = ref.keepAlive();
    final saveSettings = ref.read(saveNightscoutSettingsUseCaseProvider);
    state = NightscoutSettingsSaveState(isSaving: true, pendingDraft: draft);
    try {
      await saveSettings(draft);
      if (ref.mounted) state = const NightscoutSettingsSaveState();
      return true;
    } on NightscoutTokenValidationException catch (error) {
      if (ref.mounted) {
        state = NightscoutSettingsSaveState(
          failure: switch (error.issue) {
            NightscoutTokenIssue.required =>
              NightscoutSettingsSaveFailure.tokenRequired,
            NightscoutTokenIssue.invalid =>
              NightscoutSettingsSaveFailure.invalidToken,
            NightscoutTokenIssue.treatmentAccess =>
              NightscoutSettingsSaveFailure.treatmentAccess,
            NightscoutTokenIssue.unavailable =>
              NightscoutSettingsSaveFailure.verificationUnavailable,
          },
        );
      }
      return false;
    } catch (error) {
      // Network exceptions may contain credentials in the request URL.
      logE('Nightscout settings save failed (${error.runtimeType})');
      if (ref.mounted) {
        state = const NightscoutSettingsSaveState(
          failure: NightscoutSettingsSaveFailure.connection,
        );
      }
      return false;
    } finally {
      keepAlive.close();
    }
  }
}

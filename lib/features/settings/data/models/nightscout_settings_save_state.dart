import 'nightscout_settings_draft.dart';

enum NightscoutSettingsSaveFailure {
  tokenRequired,
  invalidToken,
  treatmentAccess,
  verificationUnavailable,
  connection,
}

class NightscoutSettingsSaveState {
  const NightscoutSettingsSaveState({
    this.isSaving = false,
    this.failure,
    this.pendingDraft,
  });

  final bool isSaving;
  final NightscoutSettingsSaveFailure? failure;
  final NightscoutSettingsDraft? pendingDraft;
}

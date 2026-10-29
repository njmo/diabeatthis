import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../data/models/nightscout_settings_save_state.dart';
import 'nightscout_connection_fields.dart';
import 'settings_section_card.dart';
import 'temp_target_settings_switch.dart';

class NightscoutSettingsSection extends StatelessWidget {
  const NightscoutSettingsSection({
    super.key,
    required this.urlController,
    required this.tokenController,
    required this.childNameController,
    required this.tempTargetsEnabled,
    required this.urlRequired,
    required this.saveState,
    required this.onChanged,
    required this.onTempTargetsChanged,
    required this.onSave,
  });

  final TextEditingController urlController;
  final TextEditingController tokenController;
  final TextEditingController childNameController;
  final bool tempTargetsEnabled;
  final bool urlRequired;
  final NightscoutSettingsSaveState saveState;
  final VoidCallback onChanged;
  final ValueChanged<bool> onTempTargetsChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final errorMessage = switch (saveState.failure) {
      null => null,
      NightscoutSettingsSaveFailure.tokenRequired =>
        context.lang.settingsTempTargetsTokenRequired,
      NightscoutSettingsSaveFailure.invalidToken =>
        context.lang.settingsNightscoutTokenInvalid,
      NightscoutSettingsSaveFailure.treatmentAccess =>
        context.lang.settingsNightscoutTokenTreatmentAccess,
      NightscoutSettingsSaveFailure.verificationUnavailable =>
        context.lang.settingsNightscoutTokenVerificationUnavailable,
      NightscoutSettingsSaveFailure.connection =>
        context.lang.settingsConnectionError,
    };
    return SettingsSectionCard(
      icon: Icons.cloud_outlined,
      title: 'Nightscout',
      subtitle: context.lang.settingsNightscoutSubtitle,
      children: [
        NightscoutConnectionFields(
          enabled: !saveState.isSaving,
          urlController: urlController,
          tokenController: tokenController,
          urlRequired: urlRequired,
          tokenRequired: tempTargetsEnabled,
          onChanged: (_) => onChanged(),
        ),
        TempTargetSettingsSwitch(
          enabled: !saveState.isSaving,
          value: tempTargetsEnabled,
          hasToken: tokenController.text.trim().isNotEmpty,
          onChanged: onTempTargetsChanged,
        ),
        const SizedBox(height: 16),
        TextFormField(
          enabled: !saveState.isSaving,
          controller: childNameController,
          decoration: InputDecoration(
            labelText: context.lang.settingsChildNameLabel,
            hintText: context.lang.settingsNameHint,
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saveState.isSaving ? null : onSave,
          icon: saveState.isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(context.lang.settingsSaveAndContinue),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/information_settings_switch.dart';

class LowTreatmentUploadSettingsSwitch extends StatelessWidget {
  const LowTreatmentUploadSettingsSwitch({
    super.key,
    required this.value,
    required this.hasToken,
    required this.onChanged,
    this.enabled = true,
  });
  final bool value;
  final bool hasToken;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InformationSettingsSwitch(
    title: context.lang.settingsLowTreatmentUploadTitle,
    description: context.lang.settingsLowTreatmentUploadDescription,
    subtitle: hasToken ? null : context.lang.settingsTempTargetsTokenRequired,
    value: value,
    onChanged: enabled && (hasToken || value) ? onChanged : null,
  );
}

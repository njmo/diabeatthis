import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/information_settings_switch.dart';

class TempTargetSettingsSwitch extends StatelessWidget {
  const TempTargetSettingsSwitch({
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
    title: context.lang.settingsTempTargetsTitle,
    description: context.lang.settingsTempTargetsDescription,
    subtitle: hasToken ? null : context.lang.settingsTempTargetsTokenRequired,
    value: value,
    onChanged: enabled && (hasToken || value) ? onChanged : null,
  );
}

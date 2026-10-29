import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/information_button.dart';

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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.lang.settingsTempTargetsTitle),
          subtitle: hasToken
              ? null
              : Text(context.lang.settingsTempTargetsTokenRequired),
          value: value,
          onChanged: enabled && (hasToken || value) ? onChanged : null,
        ),
      ),
      InformationButton(
        title: context.lang.settingsTempTargetsTitle,
        message: context.lang.settingsTempTargetsDescription,
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class DataSourceMirrorSwitch extends StatelessWidget {
  const DataSourceMirrorSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.lang.settingsMirrorTitle),
      subtitle: Text(context.lang.settingsMirrorSubtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

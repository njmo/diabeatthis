import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class NotificationRetrySwitch extends StatelessWidget {
  const NotificationRetrySwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(context.lang.notificationRetryTitle),
    subtitle: Text(context.lang.notificationRetryDescription),
    value: value,
    onChanged: onChanged,
  );
}

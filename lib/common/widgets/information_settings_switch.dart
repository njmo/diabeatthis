import 'package:flutter/material.dart';

import 'information_button.dart';

class InformationSettingsSwitch extends StatelessWidget {
  const InformationSettingsSwitch({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String title;
  final String description;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          value: value,
          onChanged: onChanged,
        ),
      ),
      InformationButton(title: title, message: description),
    ],
  );
}

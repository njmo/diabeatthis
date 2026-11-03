import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class ActivityIntensityField extends StatelessWidget {
  const ActivityIntensityField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?>? onChanged;

  static String label(AppLocalizations lang, String? value) => switch (value) {
    'light' => lang.activityIntensityLight,
    'moderate' => lang.activityIntensityModerate,
    'high' => lang.activityIntensityHigh,
    'very_high' => lang.activityIntensityVeryHigh,
    null => lang.activityIntensityUnspecified,
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final values = <String?>[null, 'light', 'moderate', 'high', 'very_high'];
    if (!values.contains(value)) values.add(value);
    return DropdownButtonFormField<String>(
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.lang.activityPerceivedIntensity,
      ),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item ?? '',
              child: Text(label(context.lang, item)),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (value) => onChanged!(value == '' ? null : value),
    );
  }
}

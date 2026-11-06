import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../../common/widgets/scrollable_chip_rail.dart';
import '../setup_labels.dart';
import 'setup_configuration_field_chip.dart';

class SetupFeatureOptionTile extends StatelessWidget {
  const SetupFeatureOptionTile({
    super.key,
    required this.option,
    required this.enabled,
    required this.onChanged,
  });
  final SetupFeatureOption option;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.lang.optionName(option.id)),
        subtitle: Text(context.lang.optionDescription(option.id)),
        value: enabled,
        onChanged: onChanged,
      ),
      if (option.requiredConfiguration.isNotEmpty)
        ScrollableChipRail(
          children: [
            for (final field in option.requiredConfiguration)
              SetupConfigurationFieldChip(field: field),
          ],
        ),
    ],
  );
}

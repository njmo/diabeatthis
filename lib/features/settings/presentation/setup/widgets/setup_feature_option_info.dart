import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature_option.dart';
import '../setup_labels.dart';
import 'setup_configuration_field_chip.dart';

class SetupFeatureOptionInfo extends StatelessWidget {
  const SetupFeatureOptionInfo({super.key, required this.option});
  final SetupFeatureOption option;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.optionName(option.id),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          context.lang.optionDescription(option.id),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final field in option.requiredConfiguration)
              SetupConfigurationFieldChip(field: field),
          ],
        ),
      ],
    ),
  );
}

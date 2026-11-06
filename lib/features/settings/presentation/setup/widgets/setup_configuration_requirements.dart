import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import 'setup_feature_chips.dart';

/// Shows the feature-to-field dependencies for any configuration module.
class SetupConfigurationRequirements extends StatelessWidget {
  const SetupConfigurationRequirements({
    super.key,
    required this.controller,
    required this.module,
  });
  final SetupWizardController controller;
  final SetupModule module;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in controller.requiredConfiguration.entries.where(
        (entry) => entry.key.module == module,
      )) ...[
        Text(
          context.lang.setupRequiredByFeatures(
            context.lang.configurationFieldName(entry.key),
          ),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SetupFeatureChips(features: entry.value),
        const SizedBox(height: 12),
      ],
    ],
  );
}

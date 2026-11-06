import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_configuration_field.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import 'setup_feature_chips.dart';

/// Required-field provenance is shown directly below its input.
class SetupConfigurationRequirements extends StatelessWidget {
  const SetupConfigurationRequirements({
    super.key,
    required this.controller,
    required this.field,
  });
  final SetupWizardController controller;
  final SetupConfigurationField field;
  @override
  Widget build(BuildContext context) {
    final features = controller.requiredConfiguration[field];
    if (features == null || features.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.setupRequiredByFeatures(
            context.lang.configurationFieldName(field),
          ),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SetupFeatureChips(features: features),
      ],
    );
  }
}

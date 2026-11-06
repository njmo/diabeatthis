import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_labels.dart';

class SetupRequirementChip extends StatelessWidget {
  const SetupRequirementChip({super.key, required this.requirement});
  final SetupRequirement requirement;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(setupRequirementIcon(requirement), size: 15),
    label: Text(
      context.lang.requirementName(requirement),
      style: Theme.of(context).textTheme.labelSmall,
    ),
    visualDensity: VisualDensity.compact,
    backgroundColor: requirement == SetupRequirement.backgroundExecution
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5),
  );
}

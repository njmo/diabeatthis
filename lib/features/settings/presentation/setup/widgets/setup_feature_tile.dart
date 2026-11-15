import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/widgets/scrollable_chip_rail.dart';
import '../setup_labels.dart';
import 'setup_configuration_field_chip.dart';
import 'setup_feature_help_sheet.dart';
import 'setup_icon_bubble.dart';
import 'setup_requirement_chip.dart';

class SetupFeatureTile extends StatelessWidget {
  const SetupFeatureTile({
    super.key,
    required this.feature,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.locked = false,
    this.mode = SetupDeviceMode.patient,
  });
  final SetupFeature feature;
  final SetupDeviceMode mode;
  final bool selected;
  final bool enabled;
  final bool locked;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final permissions = feature.requirements
        .where(isSetupSystemRequirement)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetupIconBubble(icon: setupFeatureIcon(feature.id)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.lang.featureName(feature.id, mode: mode),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: context.lang.setupFeatureInfo,
                      onPressed: () => SetupFeatureHelpSheet.show(
                        context,
                        feature,
                        mode: mode,
                      ),
                      icon: const Icon(Icons.info_outline, size: 19),
                    ),
                  ],
                ),
                Text(
                  context.lang.featureDescription(feature.id, mode: mode),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (feature.alwaysEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      label:
                          '${context.lang.featureName(feature.id, mode: mode)}: ${context.lang.setupBuiltInFeature}',
                      excludeSemantics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                context.lang.setupBuiltInFeature,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (locked)
                  Text(
                    context.lang.setupFamilyDisconnectBeforeDisable,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (!enabled)
                  Text(
                    context.lang.setupFamilySignInFirst,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (feature.options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.lang.setupTuneAvailable,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                if (permissions.isEmpty &&
                    feature.requiredConfiguration.isEmpty &&
                    !feature.alwaysEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.lang.setupNoPermissions,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  )
                else if (permissions.isNotEmpty ||
                    feature.requiredConfiguration.isNotEmpty)
                  ScrollableChipRail(
                    children: [
                      for (final requirement in permissions)
                        SetupRequirementChip(requirement: requirement),
                      for (final field in feature.requiredConfiguration)
                        SetupConfigurationFieldChip(field: field),
                    ],
                  ),
              ],
            ),
          ),
          if (!feature.alwaysEnabled)
            Semantics(
              label: context.lang.featureName(feature.id, mode: mode),
              child: Switch(
                value: selected,
                onChanged: enabled && !locked ? onChanged : null,
              ),
            ),
        ],
      ),
    );
  }
}

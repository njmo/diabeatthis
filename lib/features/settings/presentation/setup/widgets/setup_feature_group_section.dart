import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/setup/domain/setup_feature_group.dart';
import '../setup_labels.dart';
import 'setup_feature_tile.dart';

class SetupFeatureGroupSection extends StatelessWidget {
  const SetupFeatureGroupSection({
    super.key,
    required this.group,
    required this.features,
    required this.mode,
    required this.selected,
    required this.onChanged,
  });
  final SetupFeatureGroup group;
  final List<SetupFeature> features;
  final SetupDeviceMode mode;
  final Set<SetupFeatureId> selected;
  final void Function(SetupFeatureId, bool) onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.featureGroupName(group),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final feature in features)
                  SetupFeatureTile(
                    feature: feature,
                    mode: mode,
                    selected:
                        feature.alwaysEnabled || selected.contains(feature.id),
                    onChanged: (value) => onChanged(feature.id, value),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

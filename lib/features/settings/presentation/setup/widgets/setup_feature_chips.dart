import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/get_available_setup_features_use_case.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/widgets/scrollable_chip_rail.dart';
import '../setup_labels.dart';
import 'setup_feature_help_sheet.dart';

class SetupFeatureChips extends StatelessWidget {
  const SetupFeatureChips({super.key, required this.features});
  final Iterable<SetupFeatureId> features;
  @override
  Widget build(BuildContext context) => ScrollableChipRail(
    children: features
        .map(
          (id) => ActionChip(
            avatar: const Icon(Icons.subdirectory_arrow_right, size: 15),
            label: Text(
              context.lang.featureName(id),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            onPressed: () => SetupFeatureHelpSheet.show(
              context,
              GetAvailableSetupFeaturesUseCase.catalog.firstWhere(
                (feature) => feature.id == id,
              ),
            ),
          ),
        )
        .toList(),
  );
}

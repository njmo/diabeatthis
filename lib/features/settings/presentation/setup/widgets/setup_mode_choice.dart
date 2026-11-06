import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import 'setup_icon_bubble.dart';

class SetupModeChoice extends StatelessWidget {
  const SetupModeChoice({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSelected,
  });
  final SetupDeviceMode mode;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final patient = mode == SetupDeviceMode.patient;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SetupIconBubble(
                  icon: patient ? Icons.person_outline : Icons.favorite_outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient
                            ? context.lang.setupPatientMode
                            : context.lang.setupCaregiverMode,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        patient
                            ? context.lang.setupPatientModeDescription
                            : context.lang.setupCaregiverModeDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

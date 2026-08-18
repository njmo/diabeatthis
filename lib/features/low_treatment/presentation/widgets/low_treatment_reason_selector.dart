import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../formatters/low_treatment_context_formatters.dart';

class LowTreatmentReasonSelector extends StatelessWidget {
  const LowTreatmentReasonSelector({
    super.key,
    required this.value,
    required this.hasAapsSuggestion,
    required this.onChanged,
  });

  final LowTreatmentReason value;
  final bool hasAapsSuggestion;
  final ValueChanged<LowTreatmentReason> onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reasons = _availableReasons();
    final selectedValue = reasons.contains(value) ? value : _defaultValue();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.lowTreatmentReasonTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in reasons)
                  LowTreatmentReasonChoiceChip(
                    reason: reason,
                    selected: selectedValue == reason,
                    onSelected: () => onChanged(reason),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<LowTreatmentReason> _availableReasons() {
    return [
      if (hasAapsSuggestion) LowTreatmentReason.carbsReq,
      LowTreatmentReason.lowGlucose,
      LowTreatmentReason.fallingTrend,
      LowTreatmentReason.bgMismatch,
      LowTreatmentReason.unplannedActivity,
      LowTreatmentReason.other,
    ];
  }

  LowTreatmentReason _defaultValue() {
    return hasAapsSuggestion
        ? LowTreatmentReason.carbsReq
        : LowTreatmentReason.lowGlucose;
  }
}

class LowTreatmentReasonChoiceChip extends StatelessWidget {
  const LowTreatmentReasonChoiceChip({
    super.key,
    required this.reason,
    required this.selected,
    required this.onSelected,
  });

  final LowTreatmentReason reason;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      avatar: Icon(
        _icon(reason),
        size: 16,
        color: selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
      ),
      label: Text(lowTreatmentReasonLabel(reason, context.lang)),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: colorScheme.secondaryContainer,
      backgroundColor: colorScheme.surface,
      side: BorderSide(
        color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  IconData _icon(LowTreatmentReason reason) {
    return switch (reason) {
      LowTreatmentReason.carbsReq => Icons.auto_awesome,
      LowTreatmentReason.lowGlucose => Icons.arrow_downward,
      LowTreatmentReason.fallingTrend => Icons.trending_down,
      LowTreatmentReason.bgMismatch => Icons.sensors_off_outlined,
      LowTreatmentReason.unplannedActivity => Icons.directions_run,
      LowTreatmentReason.plannedActivity => Icons.directions_run,
      LowTreatmentReason.symptoms => Icons.arrow_downward,
      LowTreatmentReason.manual => Icons.edit_outlined,
      LowTreatmentReason.other => Icons.more_horiz,
    };
  }
}

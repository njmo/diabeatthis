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
    final colors = Theme.of(context).colorScheme;
    final reasons = _availableReasons();
    if (!reasons.contains(value)) reasons.insert(0, value);
    final selectedValue = value;

    return DropdownButtonFormField<LowTreatmentReason>(
      key: ValueKey(selectedValue),
      initialValue: selectedValue,
      isExpanded: true,
      isDense: true,
      itemHeight: null,
      menuMaxHeight: 400,
      decoration: InputDecoration(
        labelText: lang.lowTreatmentReasonTitle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: [
        for (final reason in reasons)
          DropdownMenuItem(
            value: reason,
            child: LowTreatmentReasonLabel(reason: reason),
          ),
      ],
      onChanged: (reason) {
        if (reason != null) onChanged(reason);
      },
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
}

class LowTreatmentReasonLabel extends StatelessWidget {
  const LowTreatmentReasonLabel({super.key, required this.reason});

  final LowTreatmentReason reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            _icon(reason),
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(lowTreatmentReasonLabel(reason, context.lang))),
        ],
      ),
    );
  }

  IconData _icon(LowTreatmentReason reason) {
    return switch (reason) {
      LowTreatmentReason.carbsReq => Icons.auto_awesome_rounded,
      LowTreatmentReason.lowGlucose => Icons.south_rounded,
      LowTreatmentReason.fallingTrend => Icons.trending_down,
      LowTreatmentReason.bgMismatch => Icons.sensors_off_outlined,
      LowTreatmentReason.unplannedActivity => Icons.directions_run_rounded,
      LowTreatmentReason.plannedActivity => Icons.directions_run_rounded,
      LowTreatmentReason.symptoms => Icons.south_rounded,
      LowTreatmentReason.manual => Icons.edit_outlined,
      LowTreatmentReason.other => Icons.more_horiz,
    };
  }
}

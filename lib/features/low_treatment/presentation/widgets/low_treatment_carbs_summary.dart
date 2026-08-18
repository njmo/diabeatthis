import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../providers/low_treatment_context_providers.dart';

class LowTreatmentCarbsSummary extends ConsumerWidget {
  const LowTreatmentCarbsSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final theme = Theme.of(context);
    final summary = ref.watch(lowTreatmentCarbsSummaryProvider);
    final labels = summary.when(
      data: (summary) {
        return (
          carbs: '${_formatCarbs(summary.carbsTotal)} g',
          eCarbs: '${_formatCarbs(summary.extendedCarbsTotal)} g',
        );
      },
      loading: () => (carbs: '...', eCarbs: '...'),
      error: (_, _) => (carbs: '-', eCarbs: '-'),
    );

    return Row(
      children: [
        Expanded(
          child: LowTreatmentSummaryTile(
            label: lang.mealCarbsLabel,
            value: labels.carbs,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LowTreatmentSummaryTile(label: 'eCarbs', value: labels.eCarbs),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.info_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  String _formatCarbs(num value) {
    final asDouble = value.toDouble();
    if (asDouble == asDouble.roundToDouble()) {
      return asDouble.toStringAsFixed(0);
    }

    return asDouble.toStringAsFixed(1);
  }
}

class LowTreatmentSummaryTile extends StatelessWidget {
  const LowTreatmentSummaryTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

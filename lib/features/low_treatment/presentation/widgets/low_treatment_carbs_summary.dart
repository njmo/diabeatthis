import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/low_treatment_suggestion_comparison.dart';
import '../controllers/low_treatment_context_controller.dart';
import '../providers/low_treatment_context_providers.dart';
import 'low_treatment_suggestion_status.dart';
import 'low_treatment_summary_row.dart';

class LowTreatmentCarbsSummary extends ConsumerWidget {
  const LowTreatmentCarbsSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(lowTreatmentCarbsSummaryProvider);
    final suggestedCarbs =
        ref
            .watch(lowTreatmentContextControllerProvider)
            .asData
            ?.value
            .suggestedCarbs ??
        0;
    final data = summary.asData?.value;
    final comparison = LowTreatmentSuggestionComparison(
      carbs: data?.carbsTotal ?? 0,
      suggestedCarbs: suggestedCarbs,
    );
    final color =
        data == null || comparison.status == LowTreatmentSuggestionStatus.none
        ? null
        : comparison.status == LowTreatmentSuggestionStatus.covered
        ? (theme.brightness == Brightness.dark
              ? Colors.green.shade300
              : Colors.green.shade700)
        : theme.colorScheme.error;
    final format = NumberFormat('0.#', context.lang.localeName);
    final placeholder = summary.isLoading ? '…' : '—';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 12),
        if (color != null)
          LowTreatmentSuggestionStatusBanner(
            comparison: comparison,
            color: color,
          ),
        LowTreatmentSummaryRow(
          label: context.lang.mealCarbsLabel,
          value: data == null
              ? placeholder
              : '${format.format(data.carbsTotal)} g',
          color: color,
        ),
        LowTreatmentSummaryRow(
          label: 'eCarbs',
          value: data == null
              ? placeholder
              : '${format.format(data.extendedCarbsTotal)} g',
        ),
      ],
    );
  }
}

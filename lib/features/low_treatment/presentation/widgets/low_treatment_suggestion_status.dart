import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/low_treatment_suggestion_comparison.dart';

class LowTreatmentSuggestionStatusBanner extends StatelessWidget {
  const LowTreatmentSuggestionStatusBanner({
    super.key,
    required this.comparison,
    required this.color,
  });

  final LowTreatmentSuggestionComparison comparison;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final difference = NumberFormat(
      '0.#',
      lang.localeName,
    ).format(comparison.difference);
    final status = comparison.status;
    if (status == LowTreatmentSuggestionStatus.none) {
      return const SizedBox.shrink();
    }
    final text = switch (status) {
      LowTreatmentSuggestionStatus.below => lang.lowTreatmentCoverageBelow(
        difference,
      ),
      LowTreatmentSuggestionStatus.excess => lang.lowTreatmentCoverageAbove(
        difference,
      ),
      _ => lang.lowTreatmentCoverageMet,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status == LowTreatmentSuggestionStatus.covered
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: color),
                ),
                if (status == LowTreatmentSuggestionStatus.excess) ...[
                  const SizedBox(height: 3),
                  Text(
                    lang.lowTreatmentCheckBolus,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../low_treatment/domain/models/low_treatment_review_entry.dart';

class DayLowTreatmentReviewTile extends StatelessWidget {
  final LowTreatmentReviewEntry entry;
  final bool busy;
  final Widget? relationEditor;
  final VoidCallback onLink;
  final VoidCallback onCreate;
  final VoidCallback onDismiss;
  final VoidCallback onReset;
  const DayLowTreatmentReviewTile({
    super.key,
    required this.entry,
    required this.busy,
    this.relationEditor,
    required this.onLink,
    required this.onCreate,
    required this.onDismiss,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final pending = entry.isPending;
    final time = DateFormat(
      'HH:mm',
    ).format(entry.recorded?.eatenAt ?? entry.occurredAt);
    final carbs = entry.recorded?.netCarbsGrams;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  entry.ambiguous
                      ? Icons.warning_amber
                      : pending
                      ? Icons.help_outline
                      : entry.dismissed
                      ? Icons.remove_circle_outline
                      : Icons.check_circle_outline,
                  color: pending || entry.ambiguous
                      ? Colors.amber.shade800
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.dismissed
                        ? context.lang.dayReviewNotLowAt(time)
                        : pending
                        ? context.lang.dayReviewCarbsAt(
                            time,
                            NumberFormat.decimalPattern(
                              context.lang.localeName,
                            ).format(entry.event!.carbs),
                          )
                        : context.lang.dayReviewLowAt(
                            time,
                            carbs == null
                                ? ''
                                : ' · ${NumberFormat.decimalPattern(context.lang.localeName).format(carbs.round())} g',
                          ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (entry.canReset)
                  IconButton(
                    tooltip: context.lang.dayReviewUndo,
                    onPressed: busy ? null : onReset,
                    icon: const Icon(Icons.undo),
                  ),
              ],
            ),
            if (entry.staleDecision)
              Text(context.lang.dayReviewStaleDecision)
            else if (entry.ambiguous)
              Text(context.lang.dayReviewConflict)
            else if (pending) ...[
              const SizedBox(height: 6),
              Text(context.lang.dayReviewCarbEntryNote),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onLink,
                    icon: const Icon(Icons.link),
                    label: Text(context.lang.dayReviewLink),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : onCreate,
                    icon: const Icon(Icons.add),
                    label: Text(context.lang.dayReviewAddPast),
                  ),
                  TextButton(
                    onPressed: busy ? null : onDismiss,
                    child: Text(context.lang.dayReviewNotLow),
                  ),
                ],
              ),
            ],
            if (relationEditor != null) relationEditor!,
          ],
        ),
      ),
    );
  }
}

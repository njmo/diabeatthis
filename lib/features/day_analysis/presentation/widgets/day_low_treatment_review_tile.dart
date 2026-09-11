import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../low_treatment/domain/models/low_treatment_review_entry.dart';

class DayLowTreatmentReviewTile extends StatelessWidget {
  final LowTreatmentReviewEntry entry;
  final bool busy;
  final VoidCallback onLink;
  final VoidCallback onCreate;
  final VoidCallback onDismiss;
  final VoidCallback onReset;
  const DayLowTreatmentReviewTile({
    super.key,
    required this.entry,
    required this.busy,
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
                        ? '$time · To nie było dosłodzenie'
                        : pending
                        ? '$time · Wpis ${entry.event!.carbs} g do sprawdzenia'
                        : '$time · Dosłodzenie${carbs == null ? '' : ' · ${carbs.toStringAsFixed(0)} g'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (entry.canReset)
                  IconButton(
                    tooltip: 'Cofnij decyzję',
                    onPressed: busy ? null : onReset,
                    icon: const Icon(Icons.undo),
                  ),
              ],
            ),
            if (entry.staleDecision)
              const Text(
                'Zapisana decyzja dotyczy innego wpisu. Cofnij ją, aby ponownie sprawdzić powiązanie.',
              )
            else if (entry.ambiguous)
              const Text(
                'Sprzeczne wpisy o tej samej godzinie. Najpierw sprawdź historię źródłową.',
              )
            else if (pending) ...[
              const SizedBox(height: 6),
              const Text(
                'Wpis węglowodanów nie potwierdza sam w sobie dosłodzenia.',
              ),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Połącz'),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj wstecz'),
                  ),
                  TextButton(
                    onPressed: busy ? null : onDismiss,
                    child: const Text('To nie dosłodzenie'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

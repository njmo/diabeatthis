import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../meals/presentation/helpers/meal_wizard_relation_label.dart';
import '../../domain/models/day_meal_review_entry.dart';

class DayMealReviewTile extends StatelessWidget {
  final DayMealReviewEntry entry;
  final bool busy;
  final ValueChanged<BolusWizard> onLink;
  final ValueChanged<BolusWizard> onCreate;
  final ValueChanged<int> onUnlink;

  const DayMealReviewTile({
    super.key,
    required this.entry,
    required this.busy,
    required this.onLink,
    required this.onCreate,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final meal = entry.meal;
    final linked = meal != null && entry.wizards.isNotEmpty;
    final unassigned = meal == null;
    final colors = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm').format(entry.occurredAt);
    final wizard = unassigned ? entry.wizards.single : null;
    final canLink =
        wizard != null &&
        (wizard.localId != null ||
            (wizard.nightscoutObjectId != null && wizard.remoteSource != null));
    final subtitle = wizard == null
        ? '$time · wpisy kalkulatora: ${entry.wizards.length}'
        : '$time · ${wizard.calculatorResult?.carbs?.toStringAsFixed(0) ?? '—'} g WW';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          linked
              ? Icons.check_circle
              : unassigned
              ? Icons.error
              : Icons.restaurant,
          color: linked
              ? Colors.green.shade700
              : unassigned
              ? Colors.amber.shade800
              : colors.onSurfaceVariant,
          semanticLabel: linked
              ? 'Powiązany z posiłkiem'
              : unassigned
              ? 'Do sprawdzenia'
              : 'Posiłek zapisany',
        ),
        title: Text(
          meal?.name ?? 'Wpis kalkulatora do sprawdzenia',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: unassigned
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: canLink
                        ? 'Połącz z posiłkiem'
                        : 'Brak identyfikatora wpisu',
                    onPressed: busy || !canLink ? null : () => onLink(wizard),
                    icon: const Icon(Icons.link),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'Dodaj posiłek wstecz',
                    onPressed: busy || !canLink ? null : () => onCreate(wizard),
                    icon: const Icon(Icons.add),
                  ),
                ],
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.wizards.isEmpty)
            const Text(
              'Posiłek zapisany. Brak powiązanego wpisu kalkulatora w historii tego dnia.',
            ),
          ...entry.wizards.map((wizard) {
            final assignment = entry.assignments
                .where((a) => a.matches(wizard))
                .firstOrNull;
            final carbs = wizard.calculatorResult?.carbs;
            final insulin = wizard.calculatorResult?.totalInsulin;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${DateFormat('HH:mm').format(wizard.createdAt)} · ${carbs?.toStringAsFixed(0) ?? '—'} g WW',
              ),
              subtitle: Text(
                '${assignment?.type.label ?? 'Bez przypisania'} · kalkulator: ${insulin?.toStringAsFixed(2) ?? '—'} j.',
              ),
              trailing: assignment == null
                  ? null
                  : IconButton(
                      tooltip: 'Usuń powiązanie',
                      onPressed: busy ? null : () => onUnlink(assignment.id),
                      icon: const Icon(Icons.link_off),
                    ),
            );
          }),
          if (unassigned) ...[
            const Text('Ten wpis nie potwierdza sam w sobie, że był posiłek.'),
            if (!canLink)
              const Text(
                'Brak identyfikatora wpisu. Powiązanie będzie możliwe po uzupełnieniu historii.',
              ),
          ],
        ],
      ),
    );
  }
}

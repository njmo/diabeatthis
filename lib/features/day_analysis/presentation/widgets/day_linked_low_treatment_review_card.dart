import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';

/// Several source entries can describe one recorded consumption.
class DayLinkedLowTreatmentReviewCard extends StatelessWidget {
  final RecordedLowTreatment recorded;
  final List<Treat> events;
  final bool busy;
  final ValueChanged<Treat> onReset;

  const DayLinkedLowTreatmentReviewCard({
    super.key,
    required this.recorded,
    required this.events,
    required this.busy,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(recorded.eatenAt);
    final carbs = recorded.netCarbsGrams;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.lang.dayReviewLowAt(
                time,
                carbs == null
                    ? ''
                    : ' · ${NumberFormat.decimalPattern(context.lang.localeName).format(carbs.round())} g',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(context.lang.dayReviewLinkedCount(events.length)),
            for (final event in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  '${DateFormat('HH:mm').format(event.createdAt)} · ${event.carbs} g',
                ),
                trailing: IconButton(
                  tooltip: context.lang.dayReviewUnlink,
                  onPressed: busy ? null : () => onReset(event),
                  icon: const Icon(Icons.link_off),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

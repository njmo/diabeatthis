import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/day_summary_snapshot.dart';
import 'day_summary_facts.dart';

class DaySummaryReviewForm extends StatefulWidget {
  final DaySummarySnapshot snapshot;
  final bool saving;
  final Future<void> Function(Set<int>, bool)? onAccept;
  const DaySummaryReviewForm({
    super.key,
    required this.snapshot,
    this.onAccept,
    this.saving = false,
  });

  @override
  State<DaySummaryReviewForm> createState() => DaySummaryReviewFormState();
}

class DaySummaryReviewFormState extends State<DaySummaryReviewForm> {
  final skipped = <int>{};
  bool acknowledge = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final saving = widget.saving;
    final editable = widget.onAccept != null;
    final unresolved = [
      for (var i = 0; i < snapshot.review.length; i++)
        if (snapshot.review[i].resolution == DaySummaryResolution.unresolved) i,
    ];
    final ready =
        (snapshot.limitations.isEmpty || acknowledge) &&
        unresolved.every(skipped.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dane do ${DateFormat('dd.MM.yyyy HH:mm').format(snapshot.displayTime(snapshot.asOf))}',
        ),
        if (snapshot.nightStart != null && snapshot.nightEnd != null)
          Text(
            'Noc: ${DateFormat('dd.MM HH:mm').format(snapshot.displayTime(snapshot.nightStart!))}–${DateFormat('dd.MM HH:mm').format(snapshot.displayTime(snapshot.nightEnd!))}',
          ),
        const Text(
          'Zakresy glikemii dotyczą dostępnych odczytów. Baza jest odtworzona z historii pompy.',
        ),
        if (snapshot.limitations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Niepełne dane: ${snapshot.limitations.map((key) => limitationLabels[key] ?? key).join(', ')}.',
          ),
          if (editable)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: acknowledge,
              onChanged: saving
                  ? null
                  : (value) => setState(() => acknowledge = value ?? false),
              title: const Text('Zapisz podsumowanie ze wskazanymi brakami'),
            ),
        ],
        if (unresolved.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            editable
                ? 'Wpisy do wyjaśnienia'
                : 'Świadomie pozostawione bez wyjaśnienia',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (editable)
            const Text(
              'Wróć do list dnia, aby uzupełnić wpis, albo zaznacz świadome pominięcie. Pominięcie nie oznacza, że posiłku lub dosłodzenia nie było.',
            ),
          for (final index in unresolved)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: editable ? skipped.contains(index) : true,
              onChanged: !editable || saving
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        skipped.add(index);
                      } else {
                        skipped.remove(index);
                      }
                    }),
              title: Text(
                '${DateFormat('HH:mm').format(snapshot.displayTime(snapshot.review[index].occurredAt))} · ${snapshot.review[index].kind == DaySummaryReviewKind.meal ? 'Wpis posiłkowy' : 'Możliwe dosłodzenie'}',
              ),
              subtitle: const Text('Pozostaw bez wyjaśnienia'),
            ),
        ],
        const SizedBox(height: 12),
        DaySummaryFacts(snapshot: snapshot),
        if (editable) ...[
          const SizedBox(height: 16),
          const Text(
            'Zatwierdzony zapis pozostanie niezmienny, także po synchronizacji. Późniejsze poprawki historii nie zmienią tego podsumowania.',
          ),
          FilledButton(
            onPressed: ready && !saving
                ? () => widget.onAccept!(Set.of(skipped), acknowledge)
                : null,
            child: Text(saving ? 'Zapisywanie…' : 'Zatwierdź podsumowanie'),
          ),
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Wróć do uzupełniania dnia'),
          ),
        ],
      ],
    );
  }

  static const limitationLabels = {
    'glucose': 'glikemia',
    'nightGlucose': 'glikemia w nocy',
    'deviceStatus': 'historia pompy',
    'treatments': 'historia zabiegów',
    'basal': 'baza',
    'nightBasal': 'baza w nocy',
    'meals': 'posiłki',
    'lowTreatments': 'dosłodzenia',
    'activities': 'aktywności',
    'sensorAge': 'wiek sensora',
    'podAge': 'wiek poda',
    'mealReview': 'przegląd posiłków',
    'lowTreatmentReview': 'przegląd dosłodzeń',
  };
}

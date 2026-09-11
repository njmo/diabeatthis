import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../low_treatment/domain/models/recorded_low_treatment.dart';

class DayLowTreatmentPicker extends StatelessWidget {
  final List<RecordedLowTreatment> entries;
  const DayLowTreatmentPicker({super.key, required this.entries});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .5,
      child: ListView(
        children: [
          const ListTile(
            title: Text('Wybierz zapisane dosłodzenie z tego dnia'),
          ),
          if (entries.isEmpty)
            const ListTile(
              title: Text('Brak zapisanych dosłodzeń. Użyj „Dodaj wstecz”.'),
            ),
          ...entries.map(
            (low) => ListTile(
              title: Text(
                '${DateFormat('HH:mm').format(low.eatenAt)} · ${low.netCarbsGrams?.toStringAsFixed(0) ?? '—'} g',
              ),
              trailing: const Icon(Icons.link),
              onTap: () => Navigator.of(context).pop(low.mealId),
            ),
          ),
        ],
      ),
    ),
  );
}

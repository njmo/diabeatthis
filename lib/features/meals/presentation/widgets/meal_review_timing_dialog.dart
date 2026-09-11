import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../data/models/meal_review_timing.dart';
import '../../data/models/retrospective_meal_timing.dart';
import 'add_meal/meal_planned_time_field.dart';
import 'add_meal/retrospective_meal_fields.dart';

class MealReviewTimingDialog extends StatefulWidget {
  final DateTime initialTime;
  const MealReviewTimingDialog({super.key, required this.initialTime});

  @override
  State<MealReviewTimingDialog> createState() => MealReviewTimingDialogState();
}

class MealReviewTimingDialogState extends State<MealReviewTimingDialog> {
  final formKey = GlobalKey<FormState>();
  late DateTime startedAt = widget.initialTime;
  RetrospectiveMealTiming timing = const RetrospectiveMealTiming();
  String? error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Jak przebiegał posiłek?'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sprawdź godzinę rozpoczęcia jedzenia. Podpowiedź pochodzi z kalkulatora.',
              ),
              MealPlannedTimeField(
                retrospective: true,
                initialDate: widget.initialTime,
                onChanged: (value) => startedAt = value,
              ),
              RetrospectiveMealFields(
                value: timing,
                subtitle:
                    'Zapisz kolejność i czasy. Ilości jedzenia uzupełnisz w podsumowaniu.',
                onChanged: (value) => setState(() => timing = value),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Anuluj'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          formKey.currentState!.save();
          try {
            timing.validate(startedAt, clock.now());
            Navigator.of(
              context,
            ).pop(MealReviewTiming(startedAt: startedAt, timing: timing));
          } on ArgumentError catch (failure) {
            setState(() => error = failure.message.toString());
          }
        },
        child: const Text('Potwierdź i połącz'),
      ),
    ],
  );
}

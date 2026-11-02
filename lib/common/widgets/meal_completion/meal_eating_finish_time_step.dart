import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../meal/meal_completion_timing.dart';
import '../date_time_boundary_builder.dart';
import 'meal_completion_time_section.dart';

/// Collects an explicit eating end in memory before any quantity is confirmed.
class MealEatingFinishTimeStep extends StatefulWidget {
  const MealEatingFinishTimeStep({
    super.key,
    required this.timing,
    required this.mealName,
    required this.onConfirmed,
    this.chooseEarlier = false,
  });

  final MealCompletionTiming timing;
  final String mealName;
  final ValueChanged<DateTime> onConfirmed;
  final bool chooseEarlier;

  @override
  State<MealEatingFinishTimeStep> createState() =>
      MealEatingFinishTimeStepState();
}

class MealEatingFinishTimeStepState extends State<MealEatingFinishTimeStep> {
  late bool earlier = widget.chooseEarlier;
  DateTime? endedAt;

  void confirm(DateTime? value) {
    if (widget.timing.isValidEnd(value, clock.now())) {
      widget.onConfirmed(value!);
    }
  }

  @override
  Widget build(BuildContext context) => DateTimeBoundaryBuilder(
    at: endedAt,
    builder: (context, now) => Scaffold(
      appBar: AppBar(
        title: Text(context.lang.mealEatingFinishTitle),
        leading: earlier
            ? BackButton(
                onPressed: () => setState(() {
                  earlier = false;
                  endedAt = null;
                }),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.mealName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (!earlier) ...[
              FilledButton.icon(
                onPressed: widget.timing.isValidEnd(now, now)
                    ? () => confirm(clock.now())
                    : null,
                icon: const Icon(Icons.check),
                label: Text(context.lang.mealEatingFinishedNow),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => earlier = true),
                icon: const Icon(Icons.history),
                label: Text(context.lang.mealEatingFinishedEarlier),
              ),
            ] else ...[
              MealCompletionTimeSection(
                timing: widget.timing,
                now: now,
                editing: true,
                endedAt: endedAt,
                onEndedAtChanged: (value) => setState(() => endedAt = value),
                onEditingChanged: (editing) {
                  if (!editing) confirm(endedAt);
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.timing.isValidEnd(endedAt, now)
                    ? () => confirm(endedAt)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(context.lang.mealEatingContinue),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

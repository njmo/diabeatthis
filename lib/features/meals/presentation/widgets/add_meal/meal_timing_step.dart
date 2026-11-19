import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_time_anchor.dart';
import '../../../../../common/widgets/meal_time_anchor_field.dart';
import '../../../../../common/widgets/meal_timeline_preview.dart';
import '../../../data/models/retrospective_meal_timing.dart';
import 'meal_planned_time_field.dart';
import 'retrospective_meal_fields.dart';

class MealTimingStep extends StatelessWidget {
  const MealTimingStep({
    super.key,
    required this.retrospective,
    required this.selectedDate,
    required this.onDateChanged,
    required this.timing,
    required this.onTimingChanged,
    this.calculatorDate,
    this.withoutHour = false,
    this.onWithoutHour,
    this.anchor = MealTimeAnchor.eatingStart,
    this.onAnchorChanged,
    this.onCalculatorSelected,
    this.planningHorizonDays = 5,
  });
  final bool withoutHour;
  final VoidCallback? onWithoutHour;
  final int planningHorizonDays;
  final MealTimeAnchor anchor;
  final ValueChanged<MealTimeAnchor>? onAnchorChanged;
  final VoidCallback? onCalculatorSelected;
  final bool retrospective;
  final DateTime? selectedDate;
  final DateTime? calculatorDate;
  final ValueChanged<DateTime> onDateChanged;
  final RetrospectiveMealTiming timing;
  final ValueChanged<RetrospectiveMealTiming> onTimingChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        retrospective
            ? context.lang.mealFlowPastTitle
            : context.lang.mealFlowFutureTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (retrospective && onAnchorChanged != null) ...[
        MealTimeAnchorField(value: anchor, onChanged: onAnchorChanged!),
        const SizedBox(height: 8),
        Text(
          context.lang.mealTimeAnchorHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
      ],
      if (!retrospective && onWithoutHour != null) ...[
        Semantics(
          selected: withoutHour,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: withoutHour
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            selected: withoutHour,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
            leading: Icon(
              withoutHour ? Icons.check_circle : Icons.today_outlined,
            ),
            title: Text(context.lang.mealPlanTodayWithoutHour),
            onTap: onWithoutHour,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.lang.mealPlanSpecificTime,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
      ],
      MealPlannedTimeField(
        planningHorizonDays: planningHorizonDays,
        key: ValueKey(anchor),
        showTimeLabel: retrospective,
        timeLabel: retrospective
            ? MealTimeAnchorField.label(context, anchor)
            : null,
        calculatorHint: context.lang.mealCalculatorInsulinHint,
        onCalculatorSelected: onCalculatorSelected,
        initialDate: selectedDate,
        calculatorDate: calculatorDate,
        retrospective: retrospective,
        onChanged: onDateChanged,
      ),
      if (retrospective) ...[
        const SizedBox(height: 24),
        RetrospectiveMealFields(value: timing, onChanged: onTimingChanged),
        if (selectedDate != null && (timing.eatingMinutes ?? 0) > 0) ...[
          const SizedBox(height: 16),
          MealTimelinePreview(
            startedAt: timing.startFromReference(selectedDate!, anchor),
            endedAt: timing
                .startFromReference(selectedDate!, anchor)
                .add(Duration(minutes: timing.eatingMinutes!)),
            insulinAt: timing.bolusAt(
              timing.startFromReference(selectedDate!, anchor),
            ),
          ),
        ],
      ],
    ],
  );
}

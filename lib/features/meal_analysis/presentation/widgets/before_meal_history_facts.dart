import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/before_meal_context.dart';

class BeforeMealHistoryFacts extends StatelessWidget {
  final BeforeMealContext data;
  const BeforeMealHistoryFacts({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String grams(num? value) =>
        value == null ? '—' : '${number.format(value)} g';
    String time(DateTime at) =>
        DateFormat('d.MM HH:mm', lang.localeName).format(at.toLocal());
    String empty(List<Object>? list) =>
        list == null ? lang.beforeMealUnavailable : lang.beforeMealNoEvents;
    final style = Theme.of(context).textTheme.titleSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(lang.beforeMealPreviousMeals, style: style),
        Text(
          '${time(data.asOf.subtract(data.windows.meals))}–${time(data.asOf)}',
        ),
        if (data.priorMeals?.isNotEmpty != true) Text(empty(data.priorMeals)),
        for (final meal in data.priorMeals ?? [])
          Text(
            '${time(meal.eatenAt)} · ${meal.name} · ${grams(meal.snapshot?.totalNetCarbsG)} ${lang.beforeMealCarbs}'
            '${meal.snapshot == null ? ' · ${lang.beforeMealUnknownMacros}' : ' · ${meal.snapshot!.snapshotType.name == 'planned' ? lang.beforeMealPlannedMacros : lang.beforeMealConsumedMacros}'}',
          ),
        const SizedBox(height: 12),
        Text(lang.beforeMealEcarbs, style: style),
        Text(lang.beforeMealScheduleOnly),
        if (data.extendedCarbPlans?.isNotEmpty != true)
          Text(empty(data.extendedCarbPlans)),
        for (final plan in data.extendedCarbPlans ?? [])
          Text(
            '${time(plan.treatment.createdAt)}–${time(plan.endsAt)} · ${lang.beforeMealRemaining}: ${grams(plan.scheduledAfterCutoffGrams)} / ${grams(plan.treatment.carbs)}',
          ),
        const SizedBox(height: 12),
        Text(lang.beforeMealLows, style: style),
        if (data.lowTreatments?.isNotEmpty != true)
          Text(empty(data.lowTreatments)),
        for (final low in data.lowTreatments ?? [])
          Text('${time(low.eatenAt)} · ${grams(low.netCarbsGrams)}'),
        const SizedBox(height: 12),
        Text(lang.beforeMealActivities, style: style),
        Text(
          '${time(data.asOf.subtract(data.windows.activities))}–${time(data.asOf.add(data.windows.upcomingActivities))}',
        ),
        if (data.activities?.isNotEmpty != true) Text(empty(data.activities)),
        for (final activity in data.activities ?? [])
          Text(
            '${time(activity.startedAt)} · ${activity.name} · ${activity.startedAt.isAfter(data.asOf)
                ? lang.beforeMealPlanned
                : activity.endedAt == null
                ? lang.beforeMealOngoing
                : '${lang.beforeMealEnded} ${time(activity.endedAt!)}'}',
          ),
      ],
    );
  }
}

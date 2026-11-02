import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/history_link_card.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../domain/models/before_meal_context.dart';
import '../../domain/models/extended_carb_plan_context.dart';
import '../../domain/models/meal_activity_context.dart';
import '../../domain/models/recorded_meal_context.dart';
import 'before_meal_context_cards.dart';
import 'prior_meal_card.dart';

class BeforeMealHistoryFacts extends StatelessWidget {
  final BeforeMealContext data;
  final bool precedingMealOnly;
  const BeforeMealHistoryFacts({
    super.key,
    required this.data,
    this.precedingMealOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (precedingMealOnly) return BeforeMealContextCards(data: data);
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String grams(num? value) =>
        value == null ? '—' : '${number.format(value)} g';
    String time(DateTime at) =>
        DateFormat('d.MM HH:mm', lang.localeName).format(at.toLocal());
    String empty(List<Object>? list) =>
        list == null ? lang.beforeMealUnavailable : lang.beforeMealNoEvents;
    final activities = data.activities ?? const <MealActivityContext>[];
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
        for (final meal in data.priorMeals ?? const <RecordedMealContext>[])
          PriorMealCard(meal: meal),
        const SizedBox(height: 12),
        Text(lang.beforeMealEcarbs, style: style),
        Text(lang.beforeMealScheduleOnly),
        if (data.extendedCarbPlans?.isNotEmpty != true)
          Text(empty(data.extendedCarbPlans)),
        for (final plan
            in data.extendedCarbPlans ?? const <ExtendedCarbPlanContext>[])
          Text(
            '${time(plan.treatment.createdAt)}–${time(plan.endsAt)} · ${lang.beforeMealRemaining}: ${grams(plan.scheduledAfterCutoffGrams)} / ${grams(plan.treatment.carbs)}',
          ),
        const SizedBox(height: 12),
        Text(lang.beforeMealLows, style: style),
        if (data.lowTreatments?.isNotEmpty != true)
          Text(empty(data.lowTreatments)),
        for (final low in data.lowTreatments ?? const <RecordedLowTreatment>[])
          Text('${time(low.eatenAt)} · ${grams(low.netCarbsGrams)}'),
        const SizedBox(height: 12),
        Text(lang.beforeMealActivities, style: style),
        Text(
          '${time(data.asOf.subtract(data.windows.activities))}–${time(data.asOf.add(data.windows.upcomingActivities))}',
        ),
        if (activities.isEmpty)
          Text(
            data.activities == null
                ? lang.beforeMealUnavailable
                : lang.beforeMealNoEvents,
          ),
        for (final activity in activities)
          HistoryLinkCard(
            icon: Icons.directions_run_rounded,
            title: activity.name,
            onTap: () => context.router.push(
              ActivityLogRoute(activityLogId: activity.logId),
            ),
            subtitle:
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

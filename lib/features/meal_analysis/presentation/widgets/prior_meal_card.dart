import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/history_link_card.dart';
import '../../../../core/domain/model/meal_snapshot.dart';
import '../../domain/models/recorded_meal_context.dart';

class PriorMealCard extends StatelessWidget {
  const PriorMealCard({super.key, required this.meal});
  final RecordedMealContext meal;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final snapshot = meal.snapshot;
    final time = DateFormat(
      'd.MM HH:mm',
      lang.localeName,
    ).format(meal.eatenAt.toLocal());
    final source = snapshot == null
        ? lang.beforeMealUnknownMacros
        : snapshot.snapshotType == MealSnapshotType.planned
        ? lang.beforeMealPlannedMacros
        : lang.beforeMealConsumedMacros;
    final amount = snapshot == null
        ? null
        : '${NumberFormat('0.##', lang.localeName).format(snapshot.totalNetCarbsG)} g ${lang.beforeMealCarbs}';
    return HistoryLinkCard(
      title: '${meal.name} · $time',
      subtitle: [if (amount != null) amount, source].join(' · '),
      icon: Icons.restaurant_rounded,
      onTap: () => context.router.push(MealRoute(mealId: meal.mealId)),
    );
  }
}

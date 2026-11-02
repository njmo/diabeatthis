import 'package:flutter/material.dart';

import '../../../../../common/widgets/history_entry_row.dart';
import '../../../../../common/widgets/history_status_badge.dart';
import '../../../../../core/domain/model/meal.dart' as domain;
import '../meal_details/meal_detail_formatters.dart';

class MealCard extends StatelessWidget {
  final domain.Meal meal;
  final VoidCallback onTap;

  const MealCard({super.key, required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final plannedAt = meal.plannedAt?.toLocal();
    return HistoryEntryRow(
      name: meal.name,
      onTap: onTap,
      metadata: [
        HistoryStatusBadge(label: mealStatusLabel(meal.status ?? 'planned')),
        if (plannedAt != null)
          Text(
            MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(plannedAt),
              alwaysUse24HourFormat: true,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

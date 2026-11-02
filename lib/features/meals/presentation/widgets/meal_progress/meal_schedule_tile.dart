import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_display_name.dart';
import '../../../../../core/domain/model/meal.dart';
import '../meal_details/meal_detail_formatters.dart';
import 'meal_schedule_labels.dart';

class MealScheduleTile extends StatelessWidget {
  const MealScheduleTile({
    super.key,
    required this.meal,
    required this.enabled,
    required this.onOpen,
    this.onDelete,
    this.showDate = false,
  });

  final Meal meal;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      enabled: enabled,
      onTap: enabled ? onOpen : null,
      leading: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          mealScheduleTime(context, meal.plannedAt),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(mealDisplayName(meal.name)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isQuickMealName(meal.name)) Text(lang.mealProgressQuickMeal),
          if (showDate && meal.plannedAt != null)
            Text(mealScheduleFullDate(context, meal.plannedAt!)),
          Text(mealStatusLabel(meal.status ?? 'planned')),
          if (!enabled) Text(lang.mealProgressBlocked),
        ],
      ),
      trailing: onDelete == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: lang.commonDelete,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }
}

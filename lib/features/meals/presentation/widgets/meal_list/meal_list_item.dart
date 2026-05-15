import 'package:flutter/material.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import 'meal_card.dart';
import 'meal_delete_dismiss_background.dart';

class MealListItem extends StatelessWidget {
  final domain.Meal meal;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  const MealListItem({
    super.key,
    required this.meal,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('meal-${meal.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: const MealDeleteDismissBackground(),
      child: MealCard(meal: meal, onTap: onTap),
    );
  }
}

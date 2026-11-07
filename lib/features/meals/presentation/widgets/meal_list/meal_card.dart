import 'package:flutter/material.dart';

import '../../../../../common/presentation/widgets/meal_entry_card.dart';
import '../../../../../core/domain/model/meal.dart' as domain;

class MealCard extends StatelessWidget {
  final domain.Meal meal;
  final VoidCallback onTap;

  const MealCard({super.key, required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MealEntryCard(
      name: meal.name,
      status: meal.status ?? 'planned',
      plannedAt: meal.plannedAt,
      onTap: onTap,
    );
  }
}

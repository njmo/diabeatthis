import 'package:flutter/material.dart';

import '../../../../../common/presentation/widgets/meal_entry_card.dart';
import '../../../../../core/domain/model/meal.dart' as domain;

class MealCard extends StatelessWidget {
  final domain.Meal meal;
  final VoidCallback onTap;
  final String? statusLabel;
  final VoidCallback? onRetry;

  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    this.statusLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MealEntryCard(
      name: meal.name,
      status: meal.status ?? 'planned',
      plannedAt: meal.plannedAt,
      onTap: onTap,
      statusLabel: statusLabel,
      onRetry: onRetry,
    );
  }
}

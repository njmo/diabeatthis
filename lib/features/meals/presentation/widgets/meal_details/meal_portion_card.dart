import 'package:flutter/material.dart';

import '../../../data/models/meal_details_data.dart';
import 'meal_portion_overview.dart';

class MealPortionCard extends StatelessWidget {
  const MealPortionCard({
    super.key,
    required this.details,
    this.showHeader = true,
    this.canUseLocalActions = true,
  });
  final bool showHeader;
  final bool canUseLocalActions;
  final MealDetailsData details;

  @override
  Widget build(BuildContext context) => MealPortionOverview(
    details: details,
    showHeader: showHeader,
    canUseLocalActions: canUseLocalActions,
  );
}

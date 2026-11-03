import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../../domain/models/meal_target_preparation.dart';

TimelineChartRange mealTargetPreparationRange(
  MealTargetPreparation preparation,
  AppLocalizations lang,
  Color color,
) => TimelineChartRange(
  start: preparation.target.createdAt,
  end: preparation.mealStartedAt,
  color: color,
  alpha: .16,
  label: lang.mealTargetPreparation,
  startIcon: Icons.track_changes_rounded,
  endIcon: Icons.restaurant_rounded,
  startLabel: lang.mealTargetPreparation,
  endLabel: lang.mealEatingStart,
);

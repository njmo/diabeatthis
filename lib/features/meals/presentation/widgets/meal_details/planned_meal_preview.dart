import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/swipeable_cards.dart';
import '../../models/meal_page_state.dart';
import 'meal_portion_card.dart';
import 'meal_preview_header.dart';

/// A planned meal keeps only its portion tab, without review or action panels.
class PlannedMealPreview extends HookWidget {
  const PlannedMealPreview({super.key, required this.state});
  final MealPageState state;

  @override
  Widget build(BuildContext context) {
    final controller = useTabController(
      initialLength: 1,
      keys: [state.details.meal.id],
    );
    return SwipeableCards(
      key: ValueKey(('planned-meal', state.details.meal.id)),
      controller: controller,
      showPageControls: false,
      header: MealPreviewHeader(state: state),
      labels: [context.lang.mealPortionCardTitle],
      children: [MealPortionCard(details: state.details, showHeader: false)],
    );
  }
}

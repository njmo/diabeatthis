import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../features/meal_summary/presentation/screens/meal_completion_view.dart';
import '../../features/meal_summary/presentation/widgets/meal_completion_entry.dart';

/// The common completion entry keeps the everyday choice on the current screen.
Future<void> openMealCompletion(
  BuildContext context, {
  required int mealId,
  DateTime? confirmedEatingEndedAt,
  bool chooseEarlier = false,
  StackRouter? router,
}) async {
  final navigator = router?.navigatorKey.currentState ?? Navigator.of(context);
  final presentationContext = router?.navigatorKey.currentContext ?? context;
  final editAt = await showModalBottomSheet<DateTime>(
    context: presentationContext,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    showDragHandle: false,
    builder: (_) => MealCompletionEntry(
      mealId: mealId,
      confirmedEatingEndedAt: confirmedEatingEndedAt,
      chooseEarlier: chooseEarlier,
      compactChoice: true,
    ),
  );
  if (editAt == null || !navigator.mounted) return;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => MealCompletionView(
        mealId: mealId,
        confirmedEatingEndedAt: editAt,
        startAdjusted: true,
      ),
    ),
  );
}

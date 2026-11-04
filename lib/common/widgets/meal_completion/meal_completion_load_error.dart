import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart' as routes;
import '../../l10n/language.dart';
import '../../meal/recorded_meal_conversion_unavailable.dart';
import 'meal_conversion_repair_button.dart';

/// Keeps failed completion usable without treating unknown grams as zero.
class MealCompletionLoadError extends StatelessWidget {
  final Object error;
  final int mealId;
  final bool inSheet;
  final VoidCallback onRetry;

  const MealCompletionLoadError({
    super.key,
    required this.error,
    required this.mealId,
    required this.onRetry,
    this.inSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final missingConversion = error is RecordedMealConversionUnavailable;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lang.mealCompletionUnavailableTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (inSheet)
                  IconButton(
                    tooltip: lang.commonCloseTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              missingConversion
                  ? lang.mealCompletionMissingConversion
                  : lang.mealSummaryLoadError(error),
            ),
            const SizedBox(height: 16),
            if (missingConversion) ...[
              MealConversionRepairButton(mealId: mealId, onRepaired: onRetry),
              const SizedBox(height: 8),
            ],
            if (missingConversion)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.restaurant_rounded),
                label: Text(lang.mealCompletionViewRecordedMeal),
                onPressed: () {
                  final router = context.router;
                  if (inSheet) Navigator.of(context).pop();
                  router.push(routes.MealRoute(mealId: mealId));
                },
              ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(lang.mealCompletionRetryLoad),
            ),
          ],
        ),
      ),
    );
  }
}

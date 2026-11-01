import 'package:flutter/material.dart';

import '../../../features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import '../../l10n/language.dart';

class MealAdviceUnavailable extends StatelessWidget {
  const MealAdviceUnavailable({super.key, this.reason, this.onRetry});

  final MealAdviceEligibility? reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (reason == MealAdviceEligibility.available) {
      return const SizedBox.shrink();
    }
    final detail = switch (reason) {
      MealAdviceEligibility.insufficientReadings =>
        context.lang.mealAdviceInsufficientReadings,
      MealAdviceEligibility.staleReadings =>
        context.lang.mealAdviceStaleReadings,
      MealAdviceEligibility.discontinuousReadings =>
        context.lang.mealAdviceDiscontinuousReadings,
      MealAdviceEligibility.historyUnavailable =>
        context.lang.mealAdviceHistoryUnavailable,
      MealAdviceEligibility.missingDeviceStatus =>
        context.lang.mealAdviceMissingDeviceStatus,
      MealAdviceEligibility.staleDeviceStatus =>
        context.lang.mealAdviceStaleDeviceStatus,
      MealAdviceEligibility.incompleteDeviceStatus =>
        context.lang.mealAdviceIncompleteDeviceStatus,
      MealAdviceEligibility.invalidDeviceStatus =>
        context.lang.mealAdviceInvalidDeviceStatus,
      MealAdviceEligibility.available || null => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          detail == null
              ? context.lang.mealAdviceFreshDataRequirements
              : context.lang.mealAdviceUnavailableDetail(detail),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.lang.mealAdviceRetry),
          ),
        ],
      ],
    );
  }
}

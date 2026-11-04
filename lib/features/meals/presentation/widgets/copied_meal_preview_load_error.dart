import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/recorded_meal_conversion_unavailable.dart';
import '../../../../common/widgets/meal_completion/meal_conversion_repair_button.dart';
import '../../../../core/logger/logger.dart';

class CopiedMealPreviewLoadError extends HookWidget {
  const CopiedMealPreviewLoadError({
    super.key,
    required this.error,
    required this.stackTrace,
    required this.mealId,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stackTrace;
  final int? mealId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      Log.e(
        'CopiedMealPreview',
        'Failed to load meal ingredients: mealId=$mealId',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }, [error]);
    final missingConversion =
        error is RecordedMealConversionUnavailable && mealId != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (missingConversion) ...[
            Text(context.lang.copiedMealMissingConversion),
            const SizedBox(height: 12),
            MealConversionRepairButton(mealId: mealId!, onRepaired: onRetry),
          ],
          TextButton(
            onPressed: onRetry,
            child: Text(context.lang.copiedMealLoadRetry),
          ),
        ],
      ),
    );
  }
}

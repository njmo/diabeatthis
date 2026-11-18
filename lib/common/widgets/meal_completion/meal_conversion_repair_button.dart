import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/language.dart';
import '../../meal/recorded_meal_conversion_controller.dart';
import 'recorded_meal_conversion_review_page.dart';

class MealConversionRepairButton extends ConsumerWidget {
  const MealConversionRepairButton({
    super.key,
    required this.mealId,
    required this.onRepaired,
  });
  final int mealId;
  final VoidCallback onRepaired;

  Future<void> review(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(
      recordedMealConversionControllerProvider(mealId).notifier,
    );
    final requests = await controller.begin();
    if (requests == null || !context.mounted) return;
    if (requests.isEmpty) {
      onRepaired();
      return;
    }
    final repaired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecordedMealConversionReviewPage(
          mealId: mealId,
          requests: requests,
        ),
      ),
    );
    if (!context.mounted) return;
    if (repaired == true) {
      onRepaired();
    } else {
      controller.cancel();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordedMealConversionControllerProvider(mealId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: state.isLoading ? null : () => review(context, ref),
          icon: state.isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.scale_rounded),
          label: Text(context.lang.mealConversionRepairAction),
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.lang.mealConversionSaveFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

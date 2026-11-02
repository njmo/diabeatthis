import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_display_name.dart';
import '../../../meals/data/providers/meal_activation_guard_provider.dart';
import '../../domain/use_cases/finalize_meal_summary_use_case.dart';
import '../../domain/utils/meal_add_on_status.dart';
import '../models/meal_summary_draft.dart';
import '../utils/meal_summary_carbs_delta.dart';

class MealCompletionAddOnAction extends ConsumerWidget {
  const MealCompletionAddOnAction({
    super.key,
    required this.draft,
    this.openLegacySummary,
  });

  final MealSummaryDraft draft;
  final Future<void> Function()? openLegacySummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!mealSummaryCanFinish(draft.mealStatus) ||
        mealSummaryHasReportedAddOn(
          status: draft.mealStatus,
          usesReportedBaseline: calculateMealSummaryCarbsDelta(
            draft,
          ).usesReportedBaseline,
        )) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.add_circle_outline),
      label: Text(context.lang.mealSummaryExtraTitle),
      onPressed: () async {
        ref.invalidate(mealBlockingActivationProvider(draft.mealId));
        final blockingMeal = await ref.read(
          mealBlockingActivationProvider(draft.mealId).future,
        );
        if (!context.mounted) return;
        if (blockingMeal != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.lang.mealStatusActivationBlocked(
                  mealDisplayName(blockingMeal.name),
                ),
              ),
            ),
          );
          return;
        }
        if (openLegacySummary != null) {
          await openLegacySummary!();
        } else {
          await context.router.replace(MealSummaryRoute(mealId: draft.mealId));
        }
      },
    );
  }
}

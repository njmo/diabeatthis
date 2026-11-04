import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/meal_category_field.dart';
import '../../../../../common/widgets/review_section_header.dart';
import '../../../data/model/copied_meal_type.dart';
import '../../../data/models/retrospective_meal_timing.dart';
import '../../../data/providers/meal_draft_provider.dart';
import '../copied_meal_source_card.dart';
import '../meal_ingredient_preview_tile.dart';
import 'meal_review_name.dart';
import 'meal_review_nutrition.dart';
import 'meal_review_timing.dart';

class MealReviewStep extends ConsumerWidget {
  const MealReviewStep({
    super.key,
    required this.onChangeComposition,
    required this.onChangeTime,
    this.source,
    this.timing,
  });
  final VoidCallback onChangeComposition;
  final VoidCallback onChangeTime;
  final CopiedMealType? source;
  final RetrospectiveMealTiming? timing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mealDraftProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card.outlined(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MealReviewName(),
                const SizedBox(height: 8),
                MealCategoryField(
                  compact: true,
                  requiredSelection: true,
                  value: draft.category,
                  onChanged: ref.read(mealDraftProvider.notifier).setCategory,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        MealReviewTiming(
          start: draft.plannedAt,
          timing: timing,
          onChange: onChangeTime,
        ),
        const SizedBox(height: 16),
        const MealReviewNutrition(),
        ReviewSectionHeader(
          title: context.lang.mealFlowComposition,
          actionLabel: context.lang.mealFlowChange,
          onChange: onChangeComposition,
        ),
        if (source != null) ...[
          CopiedMealSourceCard(source: source!),
          const SizedBox(height: 8),
        ],
        for (final ingredient in draft.mealIngredients)
          MealIngredientPreviewTile(draft: ingredient),
      ],
    );
  }
}

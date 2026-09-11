import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../common/widgets/meal_empty_state.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../data/providers/similar_meals_provider.dart';
import 'similar_meal_glucose_preview.dart';
import 'similar_meal_tile.dart';

class SimilarMealsSection extends HookConsumerWidget {
  final MealDetailsData details;
  const SimilarMealsSection({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = useState(false);
    final provider = similarMealsProvider(details);
    final result = expanded.value ? ref.watch(provider) : null;
    final lang = context.lang;
    return Card(
      child: ExpansionTile(
        title: Tooltip(
          message: lang.similarMealsExplanation,
          child: Text(lang.similarMealsTitle),
        ),
        onExpansionChanged: (value) => expanded.value = value,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          if (result != null)
            result.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Text(lang.beforeMealLoadFailed),
              data: (data) => data == null
                  ? Text(lang.similarMealsMissingMacros)
                  : data.matches.isEmpty
                  ? MealEmptyState(message: lang.similarMealsEmpty)
                  : Column(
                      children: [
                        for (final match in data.matches)
                          Card.outlined(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            color: Theme.of(context).colorScheme.surface,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: SimilarMealTile(
                                key: ValueKey(match.meal.mealId),
                                match: match,
                                glucosePreview: SimilarMealGlucosePreview(
                                  mealId: match.meal.mealId,
                                  asOf: data.asOf,
                                ),
                                onTap: () => context.router.push(
                                  MealRoute(mealId: match.meal.mealId),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          if (result?.hasError ?? false)
            TextButton.icon(
              onPressed: result!.isLoading
                  ? null
                  : () => ref.invalidate(provider),
              icon: const Icon(Icons.refresh),
              label: Text(lang.mealAnalysisRetry),
            ),
        ],
      ),
    );
  }
}

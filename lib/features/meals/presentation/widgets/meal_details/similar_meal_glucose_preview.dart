import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/providers/similar_meal_glucose_provider.dart';
import 'similar_meal_glucose_summary.dart';

class SimilarMealGlucosePreview extends ConsumerWidget {
  final int mealId;
  final DateTime asOf;
  const SimilarMealGlucosePreview({
    super.key,
    required this.mealId,
    required this.asOf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = similarMealGlucoseProvider((mealId: mealId, asOf: asOf));
    return ref
        .watch(provider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(provider),
            child: Text(context.lang.mealAnalysisRetry),
          ),
          data: (data) => data == null
              ? Text(context.lang.beforeMealUnavailable)
              : SimilarMealGlucoseSummary(data: data),
        );
  }
}

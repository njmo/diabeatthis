import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../meal_analysis/presentation/widgets/before_meal_facts.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../data/providers/meal_before_context_provider.dart';

class MealBeforeContextSection extends HookConsumerWidget {
  final MealDetailsData details;
  const MealBeforeContextSection({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = useState(false);
    final provider = mealBeforeContextProvider((
      details: details,
      forceCloud: false,
    ));
    final result = expanded.value ? ref.watch(provider) : null;
    final lang = context.lang;
    return Card(
      child: ExpansionTile(
        title: Text(lang.beforeMealTitle),
        onExpansionChanged: (value) => expanded.value = value,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (result != null) ...[
            result.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (_, _) => Text(lang.beforeMealLoadFailed),
              data: (data) => BeforeMealFacts(
                data: data,
                hasRecordedStart: details.recordedEatingStartedAt != null,
              ),
            ),
            if (result.hasError ||
                (result.value?.failedSources.isNotEmpty ?? false))
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(lang.mealAnalysisRetry),
                onPressed: result.isLoading
                    ? null
                    : () => ref.invalidate(provider),
              ),
          ],
        ],
      ),
    );
  }
}

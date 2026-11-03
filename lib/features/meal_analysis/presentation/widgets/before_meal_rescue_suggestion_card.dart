import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/recorded_carbs_suggestion.dart';

class BeforeMealRescueSuggestionCard extends StatelessWidget {
  const BeforeMealRescueSuggestionCard({super.key, required this.suggestion});
  final RecordedCarbsSuggestion? suggestion;
  @override
  Widget build(BuildContext context) {
    final recorded = suggestion;
    if (recorded == null) return const SizedBox.shrink();
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SummaryDetailCard(
        title: lang.mealAapsCarbsSuggestion,
        icon: Icons.restaurant_outlined,
        explanation: lang.mealAapsCarbsSuggestionNote,
        child: NutritionSummaryMetric(
          label: DateFormat(
            'HH:mm',
            lang.localeName,
          ).format(recorded.at.toLocal()),
          value:
              '${NumberFormat('0.#', lang.localeName).format(recorded.grams)} g',
          detail: recorded.withinMinutes != null
              ? lang.lowTreatmentWithinInline(recorded.withinMinutes!)
              : null,
          icon: Icons.info_outline,
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../data/models/meal_analysis_data.dart';

class MealHistoryStatus extends StatelessWidget {
  const MealHistoryStatus({super.key, required this.analysis});

  final MealAnalysisData? analysis;

  @override
  Widget build(BuildContext context) {
    final data = analysis;
    if (data == null) return const SizedBox.shrink();
    final messages = context.lang;
    final coverage = data.glucoseCoverage;
    return DetailSectionCard(
      title: data.needsHistoryDownload
          ? messages.mealHistoryIncomplete
          : messages.mealHistoryAvailable,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            messages.mealHistoryCoverage(coverage.available, coverage.expected),
          ),
        ),
        if (!data.hasFullGlucoseWindow)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(messages.mealHistoryWindowInProgress),
          ),
      ],
    );
  }
}

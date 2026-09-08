import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';

class MealHistoryStatus extends StatelessWidget {
  const MealHistoryStatus({super.key, required this.analysis});

  final MealAnalysisData? analysis;

  @override
  Widget build(BuildContext context) {
    final data = analysis;
    if (data == null) return const SizedBox.shrink();
    final messages = context.lang;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${messages.mealReviewTimeReference}: ${mealTime(data.mealTime)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              Text(messages.mealReviewTimeNote),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

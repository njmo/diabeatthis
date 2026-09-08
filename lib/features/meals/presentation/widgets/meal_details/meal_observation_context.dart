import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';

class MealObservationContext extends StatelessWidget {
  final MealAnalysisData analysis;

  const MealObservationContext({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    return DetailSectionCard(
      title: messages.mealReviewRecordedBoluses,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analysis.totalInsulinUnits > 0
                    ? '${NumberFormat('0.##', messages.localeName).format(analysis.totalInsulinUnits)} j.'
                    : messages.mealReviewNoBolus,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${mealDateTime(analysis.eventStart)} – ${mealDateTime(analysis.eventEnd)}',
              ),
              const SizedBox(height: 8),
              Text(messages.mealReviewBolusContext),
              if (analysis.linkedMeals.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(messages.mealReviewOtherMeals),
              ],
              if (analysis.linkedActivities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(messages.mealReviewActivity),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

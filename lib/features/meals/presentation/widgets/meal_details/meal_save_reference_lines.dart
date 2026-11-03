import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../domain/models/meal_application_review.dart';
import 'meal_detail_formatters.dart';

class MealSaveReferenceLines extends StatelessWidget {
  const MealSaveReferenceLines({
    super.key,
    required this.details,
    required this.review,
    this.referenceTime,
  });
  final MealDetailsData details;
  final MealApplicationReview review;
  final DateTime? referenceTime;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final decision = details.advisorDecision;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${lang.mealPlannedTimeReference}: ${mealDateTime(details.meal.plannedAt.toLocal())}',
        ),
        if (referenceTime != null)
          Text(
            '${lang.mealReviewTimeReference}: ${mealDateTime(referenceTime!.toLocal())}',
          ),
        if (decision != null) ...[
          Text(
            '${lang.mealAdvisorVersionLabel}: ${decision.version?.toString() ?? lang.beforeMealUnavailable}',
          ),
          if (review.proposedWait != null) ...[
            Text(
              '${lang.mealAdvisorFinalWaitLabel}: ${lang.durationMinutesShort(decision.finalWaitTime)}',
            ),
            Text(
              '${lang.mealAdvisorWaitIgnoredLabel}: ${decision.waitTimeIgnored ? lang.commonYes : lang.commonNo}',
            ),
          ],
        ],
        if (details.meal.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            lang.mealNotesLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(details.meal.notes!),
        ],
      ],
    );
  }
}

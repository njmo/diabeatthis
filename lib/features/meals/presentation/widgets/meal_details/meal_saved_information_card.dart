import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../common/widgets/meal_save_timeline.dart';
import '../../controllers/meal_application_review_controller.dart';
import '../../models/meal_page_state.dart';
import 'meal_detail_formatters.dart';
import 'meal_save_reference_lines.dart';

class MealSavedInformationCard extends StatelessWidget {
  const MealSavedInformationCard({super.key, required this.state});
  final MealPageState state;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final meal = state.details.meal;
    const controller = MealApplicationReviewController();
    return SummaryDetailCard(
      title: lang.mealSaveAndSync,
      icon: Icons.cloud_done_outlined,
      explanation: state.analysis == null ? null : lang.mealReviewTimeNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                meal.isSynced ? Icons.cloud_done_outlined : Icons.phone_android,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${lang.mealSyncLabel}: ${meal.isSynced ? lang.mealSynced : lang.mealLocal}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MealSaveTimeline(
            events: controller.savedEvents(state.details),
            formatTime: (at) => mealDateTime(at.toLocal()),
          ),
          const SizedBox(height: 16),
          MealSaveReferenceLines(
            details: state.details,
            review: controller.build(state),
            referenceTime: state.analysis?.mealTime,
          ),
        ],
      ),
    );
  }
}

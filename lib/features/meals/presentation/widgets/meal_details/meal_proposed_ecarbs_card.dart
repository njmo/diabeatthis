import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../common/widgets/duration_schedule_bar.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../domain/models/meal_ecarbs_proposal.dart';
import '../../controllers/meal_application_review_controller.dart';
import '../../models/meal_progress_now.dart';
import 'meal_detail_formatters.dart';

class MealProposedEcarbsCard extends StatelessWidget {
  const MealProposedEcarbsCard({
    super.key,
    required this.details,
    this.progress,
  });
  final MealDetailsData details;

  /// What AAPS holds for the plan while the meal is in progress.
  final MealExtendedCarbsProgress? progress;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final proposal = const MealApplicationReviewController().proposedEcarbs(
      details,
    );
    final colors = Theme.of(context).colorScheme;
    final amount = proposal.grams;
    return SummaryDetailCard(
      title: proposal.kind == MealEcarbsProposalKind.extraBolus
          ? lang.mealAdvisorExtraBolus
          : lang.mealProposedEcarbs,
      icon: Icons.schedule_rounded,
      explanation: lang.mealEcarbsProposalOnly,
      child: !proposal.hasDecision
          ? Text(lang.mealNoRecord)
          : amount == null
          ? Text(lang.mealNoProposedEcarbs)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveMetricList(
                  maxColumns: 2,
                  children: [
                    NutritionSummaryMetric(
                      label: lang.beforeMealCarbs,
                      value:
                          '${NumberFormat('0.#', lang.localeName).format(amount)} g',
                      icon: Icons.restaurant_rounded,
                      color: colors.primary,
                    ),
                    NutritionSummaryMetric(
                      label: lang.mealAdvisorReleaseStartLabel,
                      value: proposal.delayMinutes == null
                          ? lang.beforeMealUnavailable
                          : '${proposal.delayMinutes} min',
                      icon: Icons.hourglass_empty,
                      color: colors.secondary,
                    ),
                    if (proposal.kind == MealEcarbsProposalKind.extendedCarbs)
                      NutritionSummaryMetric(
                        label: lang.mealAdvisorReleaseDurationLabel,
                        value: proposal.durationMinutes == null
                            ? lang.beforeMealUnavailable
                            : '${proposal.durationMinutes} min',
                        icon: Icons.timelapse,
                        color: colors.primary,
                      ),
                  ],
                ),
                if (proposal.hasSchedule) ...[
                  const SizedBox(height: 12),
                  DurationScheduleBar(
                    delay: Duration(minutes: proposal.delayMinutes!),
                    duration: Duration(minutes: proposal.durationMinutes!),
                    label:
                        '${lang.mealAdvisorReleaseStartLabel}: ${proposal.delayMinutes} min; ${lang.mealAdvisorReleaseDurationLabel}: ${proposal.durationMinutes} min',
                  ),
                ],
                if (progress case final progress?) ...[
                  const SizedBox(height: 12),
                  _AapsStatus(progress: progress),
                ],
              ],
            ),
    );
  }
}

class _AapsStatus extends StatelessWidget {
  const _AapsStatus({required this.progress});

  final MealExtendedCarbsProgress progress;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final scheme = Theme.of(context).colorScheme;
    final entered = progress.entered;
    final from = progress.earliestStart;
    final to = progress.latestStart;
    final text = entered != null
        ? lang.mealEcarbsAapsEntered(mealTime(entered.createdAt))
        : from != null && to != null
        ? lang.mealEcarbsAapsMissing(mealTime(from), mealTime(to))
        : null;
    if (text == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          entered != null ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 20,
          color: entered != null ? scheme.primary : scheme.error,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

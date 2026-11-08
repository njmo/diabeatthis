import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../demo/meal_decision_demo_answer.dart';
import '../../remote/meal_decision_remote_request.dart';
import 'meal_decision_stage_chip.dart';

class ChildMealDecisionAnswer extends StatelessWidget {
  const ChildMealDecisionAnswer({super.key, required this.request});
  final MealDecisionRemoteRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deferred = request.answer == MealDecisionDemoAnswer.deferMeal;
    final respondedAt = request.response?['respondedAt'] as num?;
    final deferredUntil = respondedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            respondedAt.toInt(),
          ).add(Duration(minutes: request.minutes));
    final localizations = MaterialLocalizations.of(context);
    final timeLabel = deferredUntil == null
        ? null
        : localizations.formatTimeOfDay(
            TimeOfDay.fromDateTime(deferredUntil.toLocal()),
            alwaysUse24HourFormat: true,
          );
    final crossesDay =
        deferredUntil != null &&
        respondedAt != null &&
        !DateUtils.isSameDay(
          DateTime.fromMillisecondsSinceEpoch(respondedAt.toInt()),
          deferredUntil,
        );
    final deferredLabel = crossesDay
        ? '${localizations.formatMediumDate(deferredUntil)} · $timeLabel'
        : timeLabel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .07),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .35),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MealDecisionStageChip(
            label: context.lang.mealDecisionStatusAnswered,
            icon: Icons.check_circle_outline,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            context.lang.mealDecisionAnswerBy(
              request.respondingCaregiverName ?? '',
            ),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(
            deferred
                ? context.lang.mealDecisionDeferAction(request.minutes)
                : mealDecisionLabel(request.answer!.decision!),
            style: theme.textTheme.titleLarge,
          ),
          if (deferredUntil != null && deferred) ...[
            const SizedBox(height: 8),
            Text(context.lang.mealDecisionNewTime(deferredLabel!)),
          ],
          if (request.message.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(request.message, style: theme.textTheme.bodyLarge),
          ],
          if (deferred) ...[
            const SizedBox(height: 16),
            Text(
              context.lang.mealDecisionDeferExplanation,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

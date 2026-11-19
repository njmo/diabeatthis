import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../meal_decision_answer.dart';

class MealDecisionAnsweredStatus extends StatelessWidget {
  const MealDecisionAnsweredStatus({
    super.key,
    this.answer,
    this.minutes = 0,
    this.message = '',
    this.caregiverName,
    this.isAccepted = false,
    this.isTimedOut = false,
  });

  final MealDecisionAnswer? answer;
  final int minutes;
  final String message;
  final String? caregiverName;
  final bool isAccepted;
  final bool isTimedOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeoutColor = theme.colorScheme.error;
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final statusText = isTimedOut
        ? context.lang.mealDecisionCaregiverTimedOut
        : isAccepted
        ? context.lang.mealDecisionRemoteAccepted
        : context.lang.mealDecisionStatusAnswered;

    var decisionText = '';
    if (answer != null) {
      decisionText = switch (answer!) {
        MealDecisionAnswer.insulinThenWait => minutes > 0
            ? '${context.lang.manualMealInsulinWaitEat} (${context.lang.mealDecisionDuration(minutes)})'
            : context.lang.manualMealInsulinWaitEat,
        MealDecisionAnswer.insulinAndEat =>
          context.lang.manualMealInsulinAndEat,
        MealDecisionAnswer.eatThenInsulin =>
          context.lang.manualMealEatThenInsulin,
        MealDecisionAnswer.deferMeal =>
          context.lang.mealDecisionDeferAction(minutes),
      };
    }

    if (decisionText.isEmpty && message.isEmpty && !isAccepted && !isTimedOut) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: isDark ? Colors.green.shade400 : Colors.green.shade800,
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(statusText)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isTimedOut
            ? timeoutColor.withValues(alpha: .10)
            : isAccepted
            ? (isDark
                ? Colors.green.shade900.withValues(alpha: 0.25)
                : Colors.green.shade50)
            : (isDark
                ? const Color(0xFF00A3FF).withValues(alpha: 0.15)
                : const Color(0xFF00A3FF).withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTimedOut
              ? timeoutColor.withValues(alpha: .45)
              : isAccepted
              ? (isDark
                  ? Colors.green.shade700.withValues(alpha: 0.5)
                  : Colors.green.shade200)
              : (isDark
                  ? const Color(0xFF00A3FF).withValues(alpha: 0.3)
                  : const Color(0xFF00A3FF).withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isTimedOut
                    ? Icons.schedule
                    : isAccepted
                    ? Icons.check_circle_rounded
                    : Icons.mark_chat_read_outlined,
                size: 15,
                color: isTimedOut
                    ? timeoutColor
                    : isAccepted
                    ? (isDark ? Colors.green.shade400 : Colors.green.shade700)
                    : const Color(0xFF00A3FF),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isTimedOut
                        ? timeoutColor
                        : isAccepted
                        ? (isDark
                            ? Colors.green.shade400
                            : Colors.green.shade700)
                        : const Color(0xFF00A3FF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (decisionText.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              decisionText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: numColor,
              ),
            ),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '"$message"',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

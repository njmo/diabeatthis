import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'meal_treatment_surplus_warning.dart';

class ActiveMealProgressCard extends StatelessWidget {
  const ActiveMealProgressCard({
    super.key,
    required this.name,
    required this.status,
    required this.schedule,
    required this.steps,
    required this.actionLabel,
    required this.onAction,
    required this.onInterrupt,
    this.quickMeal = false,
    this.footer,
    this.onDelete,
    this.onEarlierFinished,
    this.onAddFood,
    this.addFoodLabel,
    this.progressAction,
    this.treatmentSurplus = false,
  });

  final String name;
  final String status;
  final String schedule;
  final Widget steps;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onInterrupt;
  final bool quickMeal;
  final Widget? footer;
  final VoidCallback? onDelete;
  final VoidCallback? onEarlierFinished;
  final VoidCallback? onAddFood;
  final String? addFoodLabel;
  final Widget? progressAction;
  final bool treatmentSurplus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final numColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nagłówek: Chip statusu + harmonogram + przyciski
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (quickMeal
                                ? const Color(0xFFFF9500)
                                : const Color(0xFF00A3FF))
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    quickMeal ? lang.mealProgressQuickMeal : status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: quickMeal
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF00A3FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    schedule,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: mutedColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: lang.commonDelete,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: mutedColor,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                IconButton(
                  tooltip: lang.mealProgressInterrupt,
                  onPressed: onInterrupt,
                  icon: const Icon(Icons.close, size: 18),
                  color: mutedColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Nazwa posiłku
            Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: numColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (quickMeal) ...[
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: mutedColor,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Paski kroków (steps)
            steps,
            if (treatmentSurplus) ...[
              const SizedBox(height: 8),
              const MealTreatmentSurplusWarning(),
            ],
            if (progressAction != null) ...[
              const SizedBox(height: 8),
              progressAction!,
            ],
            if (onAction != null || onAddFood != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onAction != null)
                    Expanded(
                      flex: 7,
                      child: SizedBox(
                        height: 38,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00A3FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onAction,
                          child: Text(
                            actionLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onAddFood != null) ...[
                    if (onAction != null) const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF0F172A),
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onAddFood,
                          child: Text(
                            addFoodLabel ?? lang.mealProgressAddFood,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (onEarlierFinished != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onEarlierFinished,
                  child: Text(
                    lang.mealEatingFinishedEarlier,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
            ],
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

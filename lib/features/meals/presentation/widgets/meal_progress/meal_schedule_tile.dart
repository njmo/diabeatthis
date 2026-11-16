import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_display_name.dart';
import '../../../../../core/domain/model/meal.dart';
import '../meal_details/meal_detail_formatters.dart';
import 'meal_schedule_labels.dart';

class MealScheduleTile extends StatelessWidget {
  const MealScheduleTile({
    super.key,
    required this.meal,
    required this.enabled,
    required this.onOpen,
    this.onDelete,
    this.showDate = false,
    this.footer,
  });

  final Meal meal;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final bool showDate;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final numColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final status = meal.status ?? 'planned';
    final isWaiting =
        status == 'waiting-for-bolus' || status == 'bolused-waiting';
    final statusColor = isWaiting
        ? const Color(0xFFFF9500) // Loop orange
        : const Color(0xFF00A3FF); // Loop cyan

    final timeString = mealScheduleTime(context, meal.plannedAt);

    final detailsParts = <String>[
      if (meal.carbs != null && meal.carbs! > 0) '${meal.carbs}g WW',
      if (meal.insulin != null && meal.insulin! > 0) '${meal.insulin} U',
      mealStatusLabel(status),
      if (isQuickMealName(meal.name)) lang.mealProgressQuickMeal,
      if (!enabled) lang.mealProgressBlocked,
    ];
    final subtitleText = detailsParts.join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 0, right: 12),
                minLeadingWidth: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: borderColor),
                ),
                tileColor: cardBg,
                enabled: enabled,
                onTap: enabled ? onOpen : null,
                leading: Container(
                  width: 58,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(17),
                    ),
                    border: Border(
                      right: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeString,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          showDate && meal.plannedAt != null
                              ? mealScheduleDateLabel(
                                  context, meal.plannedAt, DateTime.now())
                              : (status == 'planned'
                                  ? 'PLAN'
                                  : mealStatusLabel(status).toUpperCase()),
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                title: Text(
                  mealDisplayName(meal.name),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: enabled ? numColor : mutedColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: enabled ? mutedColor : const Color(0xFFEF4444),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: onDelete != null
                    ? IconButton(
                        tooltip: lang.commonDelete,
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: mutedColor,
                      )
                    : Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            footer!,
          ],
        ],
      ),
    );
  }
}

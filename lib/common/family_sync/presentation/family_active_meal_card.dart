import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../meal/meal_display_name.dart';
import '../../meal/meal_progress_plan.dart';
import '../../widgets/meal_progress/meal_progress_steps.dart';
import '../../../features/meals/presentation/widgets/meal_details/meal_detail_formatters.dart';
import '../../../features/meals/presentation/widgets/meal_progress/meal_schedule_labels.dart';

class FamilyActiveMealCard extends StatelessWidget {
  const FamilyActiveMealCard({
    super.key,
    required this.payload,
    required this.now,
    this.decisionAction,
    this.onOpen,
    this.monitoring = false,
  });

  final Map payload;
  final DateTime now;
  final Widget? decisionAction;
  final VoidCallback? onOpen;
  final bool monitoring;

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

    final name = payload['name'] as String? ?? '';
    final status = payload['status'] as String? ?? 'waiting-for-bolus';
    final plannedAtMs = payload['planned_at'] as int?;
    final plannedAt = plannedAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(plannedAtMs)
        : null;
    final schedule = mealScheduleLabel(context, plannedAt, now);
    final statusText = mealStatusLabel(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: cardBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
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
              // Nagłówek: Chip statusu + harmonogram + wskaźnik monitoringu + strzałka przejścia
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00A3FF),
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
                  if (monitoring) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: context.lang.uiMonitoringActive,
                      child: Icon(
                        Icons.monitor_heart_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  if (onOpen != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: mutedColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Nazwa posiłku
              Text(
                mealDisplayName(name),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: numColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Paski kroków (np. Bolus -> Jedzenie)
              MealProgressSteps(
                plan: mealProgressPlanForStatus(status),
              ),
              if (decisionAction != null) ...[
                const SizedBox(height: 8),
                decisionAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

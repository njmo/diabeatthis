import 'package:flutter/material.dart';

import '../../../core/domain/model/meal.dart';
import '../../../core/domain/model/meal_status_flow.dart';
import '../../../features/meals/presentation/widgets/meal_progress/meal_schedule_tile.dart';

import '../../l10n/language.dart';
import '../../presentation/widgets/meal_entry_card.dart';
import '../../widgets/meal_macro_summary.dart';
import 'family_plan_amount_label.dart';
import 'family_plan_snapshot_view.dart';

class FamilyPlannedMealCard extends StatelessWidget {
  const FamilyPlannedMealCard({
    super.key,
    required this.payload,
    required this.history,
    required this.locked,
    this.onEdit,
    this.decisionAction,
    this.onOpen,
    this.monitoring = false,
    this.requestStatusLabel,
    this.onRetry,
    this.components = const [],
    this.ingredients = const [],
    this.snapshots = const [],
    this.compact = false,
  });
  final Widget? decisionAction;
  final bool compact;
  final Map payload;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> components;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> snapshots;
  final bool locked;
  final bool monitoring;
  final String? requestStatusLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final timestamp = payload['planned_at'] as int?;
    final plannedAt = timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (compact && onOpen != null) {
      final status = payload['status'] as String;
      return MealScheduleTile(
        meal: Meal(
          id: payload['id'] as int? ?? 0,
          name: payload['name'] as String,
          status: status,
          plannedAt: plannedAt,
          plannedDay: payload['planned_day'] as String?,
          carbs: (payload['carbs'] as num?)?.toInt(),
          insulin: (payload['insulin'] as num?)?.toDouble(),
        ),
        enabled: true,
        onOpen: onOpen!,
        showDate: mealStatusReadyToSummarize(status),
        statusLabel:
            requestStatusLabel ??
            (locked && !monitoring ? context.lang.familyPlanPending : null),
        trailing: monitoring
            ? Tooltip(
                message: context.lang.uiMonitoringActive,
                child: Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: context.lang.uiMonitoringActive,
                ),
              )
            : null,
        cardDetails: onRetry == null
            ? decisionAction
            : Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (decisionAction != null) decisionAction!,
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(context.lang.familyPlanRetry),
                  ),
                ],
              ),
      );
    }
    final card = MealEntryCard(
      onRetry: onRetry,
      name: payload['name'] as String,
      status: payload['status'] as String,
      plannedAt: plannedAt,
      statusLabel:
          requestStatusLabel ??
          (locked && !monitoring ? context.lang.familyPlanPending : null),
      onTap: onOpen,
      trailing: monitoring
          ? Tooltip(
              message: context.lang.uiMonitoringActive,
              child: Icon(
                Icons.monitor_heart_outlined,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: context.lang.uiMonitoringActive,
              ),
            )
          : null,
      additionalMetadata: [
        if (plannedAt == null) Text(context.lang.mealPlanWithoutHour),
        if (decisionAction != null) decisionAction!,
      ],
      details: monitoring || onOpen != null
          ? null
          : [
              if (onOpen != null)
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(context.lang.mealReviewPageTitle),
                ),
              Text(
                plannedAt?.toLocal().toString() ??
                    (payload['planned_day'] as String? ?? ''),
              ),
              for (final row in components)
                Builder(
                  builder: (context) {
                    final item = row['payload'] as Map;
                    final ingredient =
                        ingredients
                                .where(
                                  (r) => r['id'] == '${item['ingredient_id']}',
                                )
                                .firstOrNull?['payload']
                            as Map?;
                    final name =
                        ingredient?['name'] as String? ??
                        context.lang.familyPlanAddIngredient;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: Text(
                        '${familyPlanAmountLabel(context, item, ingredient)}${item['consumed_amount'] == null ? '' : ' · ${context.lang.mealStatusAte}: ${familyPlanAmountLabel(context, item, ingredient, consumed: true)}'}',
                      ),
                    );
                  },
                ),
              for (final row in snapshots)
                Builder(
                  builder: (context) {
                    final data = row['payload'] as Map;
                    return Column(
                      children: [
                        Text(
                          data['snapshot_type'] == 'consumed'
                              ? context.lang.mealStatusAte
                              : context.lang.familyPlanScheduled,
                        ),
                        MealMacroSummary(
                          netCarbs: (data['total_net_carbs_g'] as num)
                              .toDouble(),
                          protein: (data['total_protein_g'] as num).toDouble(),
                          fat: (data['total_fat_g'] as num).toDouble(),
                          fiber: (data['total_fiber_g'] as num).toDouble(),
                          calories: (data['total_calories_kcal'] as num)
                              .toDouble(),
                        ),
                      ],
                    );
                  },
                ),
              for (final row in history)
                Text(
                  '${familyPlanExecutionLabel(context, (row['payload'] as Map)['status'] as String)} · ${DateTime.fromMillisecondsSinceEpoch((row['payload'] as Map)['created_at'] as int).toLocal()}',
                ),
              if (payload['status'] == 'planned' &&
                  payload['purpose'] == 'meal')
                TextButton(
                  onPressed:
                      components.any(
                        (r) =>
                            (r['payload'] as Map)['grams_per_portion_used'] ==
                            null,
                      )
                      ? null
                      : onEdit,
                  child: Text(context.lang.familyPlanEdit),
                ),
            ],
    );
    return monitoring || onOpen != null ? Card(child: card) : card;
  }
}

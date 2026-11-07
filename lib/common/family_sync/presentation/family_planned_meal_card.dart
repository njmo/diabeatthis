import 'package:flutter/material.dart';

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
    this.monitoring = false,
    this.components = const [],
    this.ingredients = const [],
    this.snapshots = const [],
  });
  final Map payload;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> components;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> snapshots;
  final bool locked;
  final bool monitoring;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => MealEntryCard(
    name: payload['name'] as String,
    status: payload['status'] as String,
    plannedAt: DateTime.fromMillisecondsSinceEpoch(
      payload['planned_at'] as int,
    ),
    statusLabel: monitoring
        ? context.lang.familyPlanMonitoring
        : locked
        ? context.lang.familyPlanPending
        : null,
    details: [
      Text(
        DateTime.fromMillisecondsSinceEpoch(
          payload['planned_at'] as int,
        ).toLocal().toString(),
      ),
      for (final row in components)
        Builder(
          builder: (context) {
            final item = row['payload'] as Map;
            final ingredient =
                ingredients
                        .where((r) => r['id'] == '${item['ingredient_id']}')
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
                  netCarbs: (data['total_net_carbs_g'] as num).toDouble(),
                  protein: (data['total_protein_g'] as num).toDouble(),
                  fat: (data['total_fat_g'] as num).toDouble(),
                  fiber: (data['total_fiber_g'] as num).toDouble(),
                  calories: (data['total_calories_kcal'] as num).toDouble(),
                ),
              ],
            );
          },
        ),
      for (final row in history)
        Text(
          '${familyPlanExecutionLabel(context, (row['payload'] as Map)['status'] as String)} · ${DateTime.fromMillisecondsSinceEpoch((row['payload'] as Map)['created_at'] as int).toLocal()}',
        ),
      if (payload['status'] == 'planned' && payload['purpose'] == 'meal')
        TextButton(
          onPressed:
              components.any(
                (r) => (r['payload'] as Map)['grams_per_portion_used'] == null,
              )
              ? null
              : onEdit,
          child: Text(context.lang.familyPlanEdit),
        ),
    ],
  );
}

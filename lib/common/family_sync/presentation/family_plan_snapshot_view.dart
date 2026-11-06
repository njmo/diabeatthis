import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_plan_amount_label.dart';

class FamilyPlanSnapshotView extends StatelessWidget {
  const FamilyPlanSnapshotView({
    super.key,
    required this.title,
    required this.rows,
  });
  final String title;
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      for (final row in rows.where((r) => r['deleted'] != true))
        Builder(
          builder: (context) {
            final p = row['payload'] as Map;
            final timestamp = p['planned_at'] ?? p['started_at'];
            if ([
              'meals',
              'activityOccurrences',
              'activities',
            ].contains(row['kind'])) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p['name'] ?? context.lang.familyPlanActivity}'),
                subtitle: Text(
                  [
                    if (timestamp is int)
                      DateTime.fromMillisecondsSinceEpoch(
                        timestamp,
                      ).toLocal().toString(),
                    if (p['status'] != null)
                      familyPlanExecutionLabel(context, p['status'] as String),
                  ].join(' · '),
                ),
              );
            }
            if (row['kind'] == 'ingredients') {
              return Text(
                '${p['name']} · ${context.lang.familyPlanCarbs}: ${p['carbs_per_100g']} · ${context.lang.mealProteinLabel}: ${p['protein_per_100g']} · ${context.lang.mealFatLabel}: ${p['fat_per_100g']} / 100 g',
              );
            }
            if (row['kind'] == 'mealIngredients') {
              final ingredient =
                  rows
                          .where(
                            (r) =>
                                r['kind'] == 'ingredients' &&
                                r['id'] == '${p['ingredient_id']}',
                          )
                          .firstOrNull?['payload']
                      as Map?;
              return Text(
                '${ingredient?['name'] ?? context.lang.familyPlanAmount}: ${familyPlanAmountLabel(context, p, ingredient)}',
              );
            }
            return const SizedBox.shrink();
          },
        ),
    ],
  );
}

String familyPlanExecutionLabel(BuildContext context, String status) =>
    switch (status) {
      'planned' => context.lang.familyPlanScheduled,
      'eating' => context.lang.mealStatusEating,
      'eating-extra' => context.lang.mealStatusEatingExtra,
      'eating-then-bolus' => context.lang.mealStatusEatingThenBolus,
      'bolused-waiting' => context.lang.mealStatusBolusedWaiting,
      'bolused-eating' => context.lang.mealStatusBolusedEating,
      'waited-eating' => context.lang.mealStatusWaitedEating,
      'waiting-for-bolus' => context.lang.mealStatusWaitingForBolus,
      'eaten' || 'eaten-extra' || 'eaten-bolused' => context.lang.mealStatusAte,
      'pending' => context.lang.familyPlanAwaitingConfirmation,
      'recorded' => context.lang.familyPlanCompleted,
      'skipped' || 'missed' || 'deleted' => context.lang.familyPlanSkipped,
      'summarized' => context.lang.familyPlanCompleted,
      'interrupted' => context.lang.familyPlanSkipped,
      _ => context.lang.familyPlanInProgress,
    };

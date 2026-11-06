import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_plan_snapshot_view.dart';

class FamilyPlanRequestCard extends StatelessWidget {
  const FamilyPlanRequestCard({
    super.key,
    required this.plan,
    required this.onRetry,
  });
  final Map<String, dynamic> plan;
  final VoidCallback? onRetry;
  bool isReference(Map item) => (plan['base'] as List).any(
    (row) =>
        row['kind'] == 'ingredients' &&
        row['id'] == '${item['ingredientId']}' &&
        (row['payload'] as Map)['is_reference'] == 1,
  );
  String proposalIngredientName(Map item) {
    if (item['catalogId'] != null) {
      return (plan['catalogLabels'] as Map?)?[item['catalogId']] as String? ??
          item['catalogId'] as String;
    }
    return (plan['base'] as List)
            .where(
              (row) =>
                  row['kind'] == 'ingredients' &&
                  row['id'] == '${item['ingredientId']}',
            )
            .map((row) => (row['payload'] as Map)['name'] as String)
            .firstOrNull ??
        '${item['ingredientId']}';
  }

  @override
  Widget build(BuildContext context) {
    final values = plan['values'] as Map;
    final status = plan['status'];
    final timestamp = values['plannedAt'] ?? values['startedAt'];
    return Card(
      child: ExpansionTile(
        title: Text(
          values['name'] as String? ?? context.lang.familyPlanActivity,
        ),
        subtitle: Text(
          status == 'pending'
              ? context.lang.familyPlanPending
              : status == 'applied'
              ? context.lang.familyPlanApplied
              : context.lang.familyPlanRejected,
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (status == 'pending')
            Text(context.lang.familyPlanPendingExplanation),
          if (status == 'rejected')
            Text(
              plan['reason'] == 'author-disconnected'
                  ? context.lang.familyPlanAuthorDisconnected
                  : context.lang.familyPlanConflict,
            ),
          FamilyPlanSnapshotView(
            title: context.lang.familyPlanBefore,
            rows: [
              for (final r in plan['base'] as List)
                Map<String, dynamic>.from(r as Map),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.lang.familyPlanProposal,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (timestamp is int)
            Text(
              DateTime.fromMillisecondsSinceEpoch(
                timestamp,
              ).toLocal().toString(),
            ),
          for (final item in values['ingredients'] as List? ?? const [])
            Text(
              '${proposalIngredientName(item as Map)} · ${isReference(item) ? context.lang.mealReferencePortions((item['grams'] as num) / 100) : '${item['grams']} g'}',
            ),
          if ((values['notes'] as String? ?? '').isNotEmpty)
            Text(values['notes'] as String),
          if (plan['canonicalTruncated'] == true)
            Text(context.lang.familyPlanComparisonPartial),
          if (status != 'pending')
            FamilyPlanSnapshotView(
              title: context.lang.familyPlanCurrent,
              rows: [
                for (final r in plan['canonical'] as List? ?? const [])
                  Map<String, dynamic>.from(r as Map),
              ],
            ),
          if (status == 'rejected')
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.lang.familyPlanRetry),
            ),
        ],
      ),
    );
  }
}

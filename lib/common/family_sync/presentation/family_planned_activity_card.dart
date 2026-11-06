import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_plan_snapshot_view.dart';

class FamilyPlannedActivityCard extends StatelessWidget {
  const FamilyPlannedActivityCard({
    super.key,
    required this.payload,
    required this.name,
    required this.locked,
    this.onConfirm,
    this.monitoring = false,
    this.onMove,
  });
  final Map payload;
  final String name;
  final bool locked;
  final bool monitoring;
  final VoidCallback? onConfirm;
  final VoidCallback? onMove;
  @override
  Widget build(BuildContext context) {
    final future =
        (payload['started_at'] as int) > DateTime.now().millisecondsSinceEpoch;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              DateTime.fromMillisecondsSinceEpoch(
                payload['started_at'] as int,
              ).toLocal().toString(),
            ),
            Text(
              monitoring
                  ? context.lang.familyPlanMonitoring
                  : locked
                  ? context.lang.familyPlanPending
                  : familyPlanExecutionLabel(
                      context,
                      payload['status'] as String,
                    ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (payload['status'] == 'pending' && future)
                  TextButton(
                    onPressed: onConfirm,
                    child: Text(context.lang.familyPlanConfirm),
                  ),
                if (['pending', 'planned'].contains(payload['status']) &&
                    future)
                  TextButton(
                    onPressed: onMove,
                    child: Text(context.lang.familyPlanMove),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

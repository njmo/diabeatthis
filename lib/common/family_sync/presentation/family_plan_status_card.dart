import 'package:flutter/material.dart';

import '../../../features/activity/data/models/activity_log_summary_data.dart';
import '../../../features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import '../../l10n/language.dart';
import '../../presentation/widgets/meal_entry_card.dart';
import '../family_plan_record_kind.dart';

/// Source adapter only: pending proposals use the same entity cards as the child.
class FamilyPlanStatusCard extends StatelessWidget {
  const FamilyPlanStatusCard({
    super.key,
    required this.plan,
    required this.onRetry,
  });
  final Map<String, dynamic> plan;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final values = plan['values'] as Map;
    final meal = (plan['type'] as String).endsWith('Meal');
    final definition = values['activity'] as Map?;
    final name =
        values['name'] as String? ??
        definition?['name'] as String? ??
        (plan['base'] as List? ?? [])
            .where((r) => r['kind'] == 'activities')
            .map((r) => (r['payload'] as Map)['name'] as String)
            .firstOrNull ??
        context.lang.familyPlanActivity;
    final rejected = plan['status'] == 'rejected';
    final label = rejected
        ? (plan['reason'] == 'activity-running'
              ? context.lang.familyActivityAlreadyRunning
              : context.lang.familyPlanRejected)
        : plan['status'] == 'applied'
        ? context.lang.familyPlanApplied
        : plan['type'] == 'startActivity'
        ? context.lang.familyWaitingForStart
        : context.lang.familyWaitingForAcceptance;
    final time = DateTime.fromMillisecondsSinceEpoch(
      (values['plannedAt'] ?? values['startedAt'] ?? plan['createdAt']) as int,
    );
    if (meal) {
      return MealEntryCard(
        name: name,
        status: 'planned',
        plannedAt: values['plannedDay'] == null ? time : null,
        additionalMetadata: [
          if (values['plannedDay'] != null)
            Text(context.lang.mealPlanTodayWithoutHour),
        ],
        statusLabel: label,
        onTap: rejected ? onRetry : null,
      );
    }
    return DashboardActivityCard(
      activity: ActivityLogSummaryData(
        id: 0,
        activityName: name,
        activityId: values['activityId'] as int? ?? 0,
        startedAt: time,
        endedAt: null,
        durationMinutes:
            values['durationMinutes'] as int? ??
            definition?['durationMinutes'] as int?,
      ),
      now: DateTime.now(),
      allowLocalActions: false,
      waitingLabel: label,
      trailing: rejected
          ? IconButton(
              tooltip: context.lang.familyPlanRetry,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            )
          : null,
    );
  }
}

bool showFamilyPlanStatus(
  Map<String, dynamic> plan,
  Iterable<Map<String, dynamic>> rows,
) {
  // Edits of existing records expose pending status on that record's card.
  if (plan['targetId'] != null ||
      plan['status'] == 'applied' && plan['resultId'] == null) {
    return false;
  }
  final kind = (plan['type'] as String).endsWith('Meal')
      ? 'meals'
      : plan['type'] == 'planActivity'
      ? 'activityOccurrences'
      : 'activityLogs';
  final mirrored =
      plan['resultId'] != null &&
      rows.any((r) => r['kind'] == kind && r['id'] == '${plan['resultId']}');
  return !mirrored;
}

Map<String, dynamic>? familyPlanForRecord(
  List<Map<String, dynamic>> plans,
  String kind,
  int id,
) {
  final relevant =
      plans
          .where(
            (p) =>
                p['targetId'] == id &&
                familyPlanTargetsKind(p['type'] as String, kind),
          )
          .toList()
        ..sort(
          (a, b) => ((b['createdAt'] as int?) ?? 0).compareTo(
            (a['createdAt'] as int?) ?? 0,
          ),
        );
  return relevant.firstOrNull;
}

String? familyPlanRecordLabel(
  BuildContext context,
  List<Map<String, dynamic>> plans,
  String kind,
  int id,
) {
  final plan = familyPlanForRecord(plans, kind, id);
  if (plan == null || plan['status'] == 'applied') return null;
  return plan['status'] == 'rejected'
      ? context.lang.familyPlanRejected
      : context.lang.familyWaitingForAcceptance;
}

typedef FamilyStatusEditor =
    Future<void> Function(
      String type, {
      int? targetId,
      Map<String, dynamic>? initial,
    });
VoidCallback? familyPlanRetryForRecord(
  List<Map<String, dynamic>> plans,
  String kind,
  int id,
  FamilyStatusEditor edit,
) {
  final plan = familyPlanForRecord(plans, kind, id);
  if (plan == null || plan['status'] != 'rejected') return null;
  return () => edit(
    plan['type'] as String,
    targetId: plan['targetId'] as int?,
    initial: Map<String, dynamic>.from(plan['values'] as Map),
  );
}

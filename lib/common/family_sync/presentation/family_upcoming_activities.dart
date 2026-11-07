import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/data/providers/time_now_provider.dart';
import '../../l10n/language.dart';
import '../../planning/is_upcoming_activity_occurrence.dart';
import '../../presentation/widgets/activity_upcoming_sessions_view.dart';
import '../family_access_scope.dart';
import 'family_plan_status_card.dart';
import 'family_planned_activity_card.dart';
import 'family_scope_guard.dart';

bool isUpcomingFamilyActivityPlan(Map plan) => const {
  'planActivity',
  'moveActivity',
  'confirmActivity',
  'skipActivity',
}.contains(plan['type']);

/// Firebase projection binding only. No patient scheduler or local writes.
class FamilyUpcomingActivities extends ConsumerWidget {
  const FamilyUpcomingActivities({
    super.key,
    required this.scope,
    required this.edit,
  });
  final FamilyAccessScope scope;
  final FamilyStatusEditor edit;
  bool canPlan([int? id]) {
    if (!scope.isCurrent || !scope.family.complete || scope.family.failed) {
      return false;
    }
    if (id == null) return true;
    final row = scope.family.rows['activityOccurrences/$id'];
    final payload = row?['payload'] as Map?;
    return row?['deleted'] != true &&
        payload != null &&
        const {'pending', 'planned'}.contains(payload['status']) &&
        (payload['started_at'] as int) > clock.now().millisecondsSinceEpoch &&
        !scope.family.locked('activityOccurrences', id);
  }

  void retry(Map<String, dynamic> expected, {int? occurrenceId}) {
    if (!canPlan(occurrenceId) || expected['id'] == null) return;
    final family = scope.family;
    final current = family.plans
        .where((p) => p['id'] == expected['id'])
        .firstOrNull;
    if (current == null ||
        current['status'] != 'rejected' ||
        current['type'] != expected['type'] ||
        current['targetId'] != expected['targetId']) {
      return;
    }
    if (occurrenceId != null &&
        familyPlanForRecord(
              family.plans,
              'activityOccurrences',
              occurrenceId,
            )?['id'] !=
            current['id']) {
      return;
    }
    if (occurrenceId == null &&
        !showFamilyPlanStatus(current, family.rows.values)) {
      return;
    }
    edit(
      current['type'] as String,
      targetId: current['targetId'] as int?,
      initial: Map<String, dynamic>.from(current['values'] as Map),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(timeNowProvider).asData?.value ?? clock.now();
    return FamilyScopeGuard(
      scope: scope,
      child: ListenableBuilder(
        listenable: scope.family,
        builder: (context, _) {
          final family = scope.family;
          final rows =
              family.ofKind('activityOccurrences').where((row) {
                final p = row['payload'] as Map;
                final log =
                    family.rows['activityLogs/${p['activity_log_id']}']?['payload']
                        as Map?;
                if (log != null &&
                    (log['ended_at'] != null ||
                        (log['started_at'] as int) <=
                            now.millisecondsSinceEpoch)) {
                  return false;
                }
                return isUpcomingActivityOccurrence(
                  status: p['status'] as String,
                  startedAt: p['started_at'] as int,
                  now: now,
                );
              }).toList()..sort(
                (a, b) => ((a['payload'] as Map)['started_at'] as int)
                    .compareTo((b['payload'] as Map)['started_at'] as int),
              );
          return ActivityUpcomingSessionsView(
            emptyLabel: context.lang.familyUpcomingEmpty,
            entries: [
              for (final row in rows)
                Builder(
                  builder: (context) {
                    final p = row['payload'] as Map;
                    final id = p['id'] as int;
                    final activity =
                        family.rows['activities/${p['activity_id']}']?['payload']
                            as Map?;
                    final proposal = familyPlanForRecord(
                      family.plans,
                      'activityOccurrences',
                      id,
                    );
                    return FamilyPlannedActivityCard(
                      payload: p,
                      name:
                          activity?['name'] as String? ??
                          context.lang.familyPlanActivity,
                      locked: family.locked('activityOccurrences', id),
                      monitoring: family.monitored('activityOccurrences', id),
                      requestStatusLabel: familyPlanRecordLabel(
                        context,
                        family.plans,
                        'activityOccurrences',
                        id,
                      ),
                      onRetry: canPlan(id) && proposal?['status'] == 'rejected'
                          ? () => retry(proposal!, occurrenceId: id)
                          : null,
                      onConfirm: canPlan(id)
                          ? () {
                              if (canPlan(id)) {
                                edit('confirmActivity', targetId: id);
                              }
                            }
                          : null,
                      onSkip: canPlan(id)
                          ? () {
                              if (canPlan(id)) {
                                edit('skipActivity', targetId: id);
                              }
                            }
                          : null,
                      onMove: canPlan(id)
                          ? () {
                              if (canPlan(id)) {
                                edit(
                                  'moveActivity',
                                  targetId: id,
                                  initial: {
                                    'startedAt':
                                        (family.rows['activityOccurrences/$id']!['payload']
                                            as Map)['started_at'],
                                  },
                                );
                              }
                            }
                          : null,
                    );
                  },
                ),
              for (final plan in family.plans.where(
                (p) =>
                    isUpcomingFamilyActivityPlan(p) &&
                    showFamilyPlanStatus(p, family.rows.values),
              ))
                FamilyPlanStatusCard(
                  plan: plan,
                  onRetry: canPlan() && plan['status'] == 'rejected'
                      ? () => retry(plan)
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

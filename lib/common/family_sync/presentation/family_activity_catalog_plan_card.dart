import 'package:flutter/material.dart';

import '../../../core/domain/model/activity.dart';
import '../../../core/drift/database_impl.dart' show ActivityScheduleData;
import '../../../features/activity/data/drafts/activity_draft.dart';
import '../../../features/activity/presentation/widgets/activity_definition_sheet.dart';
import '../../../features/activity/presentation/widgets/activity_schedule_sheet.dart';
import '../../l10n/language.dart';
import '../../planning/activity_schedule_values.dart';
import '../family_access_scope.dart';
import '../firebase_activity_catalog_repository.dart';
import 'family_activity_catalog_scope.dart';

bool isActivityCatalogPlan(Map plan) => [
  'createActivity',
  'updateActivity',
  'createActivitySchedule',
  'setActivityScheduleEnabled',
].contains(plan['type']);

class FamilyActivityCatalogPlanCard extends StatelessWidget {
  const FamilyActivityCatalogPlanCard({
    super.key,
    required this.scope,
    required this.plan,
  });
  final FamilyAccessScope scope;
  final Map<String, dynamic> plan;
  @override
  Widget build(BuildContext context) {
    final values = plan['values'] as Map;
    final schedulePayload = plan['type'] == 'setActivityScheduleEnabled'
        ? (scope
                  .family
                  .rows['activitySchedules/${plan['targetId']}']?['payload']
              as Map?)
        : null;
    final a =
        values['activity'] as Map? ??
        scope
                .family
                .rows['activities/${schedulePayload?['activity_id'] ?? plan['targetId']}']?['payload']
            as Map?;
    final rejected = plan['status'] == 'rejected';
    return FamilyActivityCatalogScope(
      scope: scope,
      child: Builder(
        builder: (context) => Card(
          child: ListTile(
            leading: const Icon(Icons.event_repeat),
            title: Text(
              a?['name'] as String? ?? context.lang.activityScheduleTitle,
            ),
            subtitle: Text(
              rejected
                  ? context.lang.familyPlanRejected
                  : context.lang.familyWaitingForAcceptance,
            ),
            trailing: rejected
                ? IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: context.lang.familyPlanRetry,
                    onPressed: () {
                      if (!scope.isCurrent || !scope.family.complete) return;
                      final current = scope.family.plans
                          .where((p) => p['id'] == plan['id'])
                          .firstOrNull;
                      if (current == null || current['status'] != 'rejected') {
                        return;
                      }
                      final v = current['values'] as Map;
                      if (current['type'] == 'setActivityScheduleEnabled') {
                        final p =
                            scope
                                    .family
                                    .rows['activitySchedules/${current['targetId']}']?['payload']
                                as Map?;
                        if (p == null) return;
                        final rule = ActivityScheduleData(
                          id: p['id'] as int,
                          activityId: p['activity_id'] as int,
                          weekdays: p['weekdays'] as String,
                          startMinute: p['start_minute'] as int,
                          durationMinutes: p['duration_minutes'] as int?,
                          confirmationMode: p['confirmation_mode'] as String,
                          previousDayMinute: p['previous_day_minute'] as int,
                          validFrom: p['valid_from'] as int,
                          validUntil: p['valid_until'] as int?,
                          enabled: p['enabled'] == 1,
                        );
                        FirebaseActivityCatalogRepository(scope)
                            .setScheduleEnabled(rule, v['enabled'] as bool)
                            .catchError((Object error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.lang.familyPlanFailed,
                                    ),
                                  ),
                                );
                              }
                            });
                        return;
                      }
                      final definition = v['activity'] as Map?;
                      final schedule = v['schedule'] is Map
                          ? activityScheduleFromValues(v['schedule'] as Map)
                          : null;
                      if (definition != null) {
                        final draft = current['type'] == 'createActivity'
                            ? ActivityDraft.draft(
                                name: definition['name'] as String,
                                percentagePre:
                                    definition['percentagePre'] as int,
                                percentagePost:
                                    definition['percentagePost'] as int,
                                durationMinutes:
                                    definition['durationMinutes'] as int?,
                              )
                            : ActivityDraft.existing(
                                id: current['targetId'] as int,
                                name: definition['name'] as String,
                                percentagePre:
                                    definition['percentagePre'] as int,
                                percentagePost:
                                    definition['percentagePost'] as int,
                                durationMinutes:
                                    definition['durationMinutes'] as int?,
                              );
                        showActivityDefinitionSheet(
                          context,
                          initialDraft: draft,
                          initialSchedule: schedule,
                        );
                      } else if (schedule != null) {
                        final p =
                            scope
                                    .family
                                    .rows['activities/${current['targetId']}']?['payload']
                                as Map?;
                        if (p == null) return;
                        showActivityScheduleSheet(
                          context,
                          Activity(
                            id: current['targetId'] as int,
                            name: p['name'] as String,
                            percentagePre: p['percentage_pre'] as int,
                            percentagePost: p['percentage_post'] as int,
                            durationMinutes:
                                (v['schedule'] as Map)['durationMinutes']
                                    as int?,
                          ),
                          initialDraft: schedule,
                        );
                      }
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

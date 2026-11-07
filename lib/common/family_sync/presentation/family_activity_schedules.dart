import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/activity.dart';
import '../../../core/drift/database_impl.dart' show ActivityScheduleData;
import '../../../features/activity/presentation/widgets/activity_schedule_sheet.dart';
import '../../../features/activity/presentation/widgets/activity_schedules_section.dart';
import '../../planning/activity_schedule_activation_repository.dart';
import '../family_access_scope.dart';
import 'family_activity_catalog_scope.dart';

class FamilyActivitySchedules extends StatelessWidget {
  const FamilyActivitySchedules({
    super.key,
    required this.scope,
    required this.activity,
  });
  final FamilyAccessScope scope;
  final Activity activity;
  @override
  Widget build(BuildContext context) => FamilyActivityCatalogScope(
    scope: scope,
    child: Consumer(
      builder: (context, ref, _) {
        final rules = scope.family
            .ofKind('activitySchedules')
            .map((r) => r['payload'] as Map)
            .where((p) => p['activity_id'] == activity.id)
            .map(
              (p) => ActivityScheduleData(
                id: p['id'] as int,
                activityId: activity.id,
                weekdays: p['weekdays'] as String,
                startMinute: p['start_minute'] as int,
                durationMinutes: p['duration_minutes'] as int?,
                confirmationMode: p['confirmation_mode'] as String,
                previousDayMinute: p['previous_day_minute'] as int,
                validFrom: p['valid_from'] as int,
                validUntil: p['valid_until'] as int?,
                enabled: p['enabled'] == 1,
              ),
            )
            .toList();
        return ActivitySchedulesSection.controlled(
          activity: activity,
          rules: rules,
          canChangeEnabled: (rule) =>
              scope.isCurrent &&
              scope.family.complete &&
              !scope.family.locked('activitySchedules', rule.id),
          changeEnabled: (rule, enabled) => ref
              .read(activityScheduleActivationRepositoryProvider)
              .setScheduleEnabled(rule, enabled),
          onAdd: () {
            if (scope.isCurrent && scope.family.complete) {
              showActivityScheduleSheet(context, activity);
            }
          },
        );
      },
    ),
  );
}

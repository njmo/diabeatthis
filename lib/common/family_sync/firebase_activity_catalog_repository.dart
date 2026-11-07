import 'dart:convert';

import '../../core/domain/model/activity.dart';
import '../../core/drift/database_impl.dart' show ActivityScheduleData;
import '../../features/activity/data/drafts/activity_draft.dart';
import '../../features/activity/data/drafts/activity_schedule_draft.dart';
import '../planning/activity_catalog_repository.dart';
import '../planning/activity_schedule_activation_repository.dart';
import '../planning/activity_schedule_values.dart';
import '../planning/family_activity_reference.dart';
import 'family_access_scope.dart';
import 'family_plan_scope.dart';

class FirebaseActivityCatalogRepository
    implements ActivityCatalogRepository, ActivityScheduleActivationRepository {
  FirebaseActivityCatalogRepository(this.scope)
    : snapshot =
          (jsonDecode(jsonEncode(scope.family.rows.values.toList())) as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
  final List<Map<String, dynamic>> snapshot;
  final FamilyAccessScope scope;
  @override
  Future<void> setScheduleEnabled(ActivityScheduleData rule, bool enabled) =>
      FirebaseActivityCatalogRepository(
        scope,
      ).submit('setActivityScheduleEnabled', rule.id, {
        'enabled': enabled,
        'effectiveFrom': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      });
  @override
  ActivityCatalogRepository beginEdit() {
    scope.requireCurrent();
    return FirebaseActivityCatalogRepository(scope);
  }

  Future<void> submit(
    String type,
    int? target,
    Map<String, dynamic> values,
  ) async {
    scope.requireCurrent();
    final family = scope.family;
    if (type == 'setActivityScheduleEnabled' &&
        target != null &&
        family.locked('activitySchedules', target)) {
      throw StateError('Schedule has a pending change');
    }
    if (type != 'setActivityScheduleEnabled' &&
        target != null &&
        (type == 'updateActivity'
            ? family.locked('activities', target)
            : family.plans.any(
                (p) =>
                    p['status'] == 'pending' &&
                    p['targetId'] == target &&
                    [
                      'updateActivity',
                      'createActivitySchedule',
                    ].contains(p['type']),
              ))) {
      throw StateError('Activity has a pending change');
    }
    final plan = {'type': type, 'targetId': target, 'values': values};
    final base = familyPlanScope(snapshot, plan);
    if (jsonEncode(familyPlanVersions(base)) !=
        jsonEncode(
          familyPlanVersions(
            familyPlanScope(family.rows.values.toList(), plan),
          ),
        )) {
      throw StateError('Activity changed; reopen the form');
    }
    await family.submit(
      type: type,
      targetId: target,
      values: values,
      baseRows: base,
      expectedSource: scope.source!,
      expectedUid: scope.uid!,
    );
  }

  @override
  Future<Activity?> saveDefinition(
    ActivityDraft draft, {
    ActivityScheduleDraft? schedule,
  }) async {
    validateFamilyActivityDefinition(draft);
    if (schedule != null &&
        !activityScheduleIsValid(
          schedule,
          duration: draft.durationMinutes,
          maximumDuration: 1440,
          cloud: true,
        )) {
      throw ArgumentError('Invalid activity schedule');
    }
    final values = {
      'activity': {
        'name': draft.name.trim(),
        'percentagePre': draft.percentagePre,
        'percentagePost': draft.percentagePost,
        'durationMinutes': draft.durationMinutes,
      },
      'schedule': schedule == null
          ? null
          : activityScheduleValues(schedule, draft.durationMinutes),
    };
    await draft.map(
      draft: (_) => submit('createActivity', null, values),
      existing: (item) => submit('updateActivity', item.id, values),
    );
    return null;
  }

  @override
  Future<void> addSchedule(
    Activity activity,
    ActivityScheduleDraft schedule,
    int? duration,
  ) {
    if (!activityScheduleIsValid(
      schedule,
      duration: duration,
      maximumDuration: 1440,
      cloud: true,
    )) {
      throw ArgumentError('Invalid activity schedule');
    }
    return submit('createActivitySchedule', activity.id, {
      'schedule': activityScheduleValues(schedule, duration),
    });
  }
}

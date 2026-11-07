import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/activity/data/drafts/activity_draft.dart';
import '../../../features/activity/data/drafts/activity_schedule_draft.dart';
import '../../../features/activity/data/mappers/activity_draft_mapper.dart';
import '../../../features/activity/data/providers/activity_provider.dart';
import '../../../features/activity/presentation/widgets/activity_definition_sheet.dart';
import '../../../features/activity/presentation/widgets/activity_picker_sheet.dart';
import '../../../features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import '../../l10n/language.dart';
import '../../planning/activity_schedule_values.dart';
import '../../planning/family_activity_reference.dart';
import '../../planning/family_planning_failure_message.dart';
import '../../planning/firebase_planning_repository.dart';
import '../../planning/planning_repository_provider.dart';
import '../../presentation/collections/controllers/caregiver_activities_controller.dart';

/// Only source binding: activity selection, timing and layout are shared.
class FamilyActivityPlanForm extends HookWidget {
  const FamilyActivityPlanForm({
    super.key,
    required this.rows,
    required this.onSubmit,
    this.onActivitySubmit,
    this.initial,
    this.operation = 'planActivity',
    this.moveOnly = false,
    this.targetId,
  });
  final Future<void> Function(String, Map<String, dynamic>)? onActivitySubmit;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? initial;
  final String operation;
  final bool moveOnly;
  final int? targetId;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  @override
  Widget build(BuildContext context) {
    final schedule = useState<ActivityScheduleDraft?>(
      initial?['schedule'] is Map
          ? activityScheduleFromValues(initial!['schedule'] as Map)
          : null,
    );
    final initialInline = useMemoized(() => familyInlineActivity(initial), [
      initial,
    ]);
    final scheduledDraft = useState<ActivityDraft?>(initialInline);
    Future<ActivityDraft?> create(
      BuildContext context, {
      ActivityDraft? initialDraft,
    }) async {
      ActivityScheduleDraft? accepted;
      final result = await showActivityDefinitionDraftSheet(
        context,
        initialDraft: initialDraft,
        initialSchedule: initialDraft == scheduledDraft.value
            ? schedule.value
            : null,
        onScheduleAccepted: (value) => accepted = value,
      );
      if (result != null) {
        schedule.value = accepted;
        scheduledDraft.value = result;
      }
      return result;
    }

    final activities = CaregiverActivitiesController(
      rows: rows,
      open: null,
      onRetry: () {},
    ).state.items;
    final occurrence =
        rows
                .where(
                  (r) =>
                      r['kind'] == 'activityOccurrences' &&
                      r['deleted'] != true &&
                      r['id'] == '$targetId',
                )
                .firstOrNull?['payload']
            as Map?;
    final activityId = initial?['activityId'] ?? occurrence?['activity_id'];
    final activity = activities.where((a) => a.id == activityId).firstOrNull;
    final repository = FirebasePlanningRepository(
      submit: (type, _, values) =>
          onActivitySubmit?.call(type, values) ?? onSubmit(values),
    );
    return ProviderScope(
      overrides: [
        planningRepositoryProvider.overrideWithValue(repository),
        activityDraftProvider.overrideWith(ActivityDraftNotifier.new),
        activitiesByQueryProvider.overrideWith(
          (ref, query) async => activities
              .where((a) => a.name.toLowerCase().contains(query.toLowerCase()))
              .toList(),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) => DashboardActivitySheet(
          initialActivity: activity?.toDraft() ?? initialInline,
          initialMode: operation == 'startActivity'
              ? ActivityEntryMode.now
              : operation == 'logActivity'
              ? ActivityEntryMode.historical
              : ActivityEntryMode.planned,
          lockMode: moveOnly,
          allowActivityChangeWhenLocked: !moveOnly,
          allowClearDraftSelection: true,
          showDuration: !moveOnly,
          requirePlannedDuration: true,
          maximumDuration: 1440,
          initialStart: DateTime.fromMillisecondsSinceEpoch(
            initial?['startedAt'] as int? ??
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
          ),
          initialDuration:
              initial?['durationMinutes'] as int? ??
              (initial?['endedAt'] is int && initial?['startedAt'] is int
                  ? ((initial!['endedAt'] as int) -
                            (initial!['startedAt'] as int)) ~/
                        60000
                  : null) ??
              occurrence?['duration_minutes'] as int?,
          activityEditor: (context, activity) => activity.map(
            draft: (_) => create(context, initialDraft: activity),
            existing: (_) =>
                showActivityPickerSheet(context, createActivity: create),
          ),
          picker: (context) =>
              showActivityPickerSheet(context, createActivity: create),
          submittingLabel: context.lang.familySendingToChild,
          saveErrorMessage: (context, error) =>
              familyPlanningFailureMessage(context.lang, error),
          onSubmit: (action) async {
            final storage = ref.read(planningRepositoryProvider);
            if (moveOnly) {
              if (targetId == null) throw StateError('Missing occurrence');
              await storage.moveActivity(targetId!, action.startedAt);
            } else {
              await storage.saveActivity(
                DashboardActivityAction(
                  activity: action.activity,
                  startedAt: action.startedAt,
                  isScheduled: action.isScheduled,
                  endedAt: action.endedAt,
                  durationMinutes: action.durationMinutes,
                  schedule: identical(scheduledDraft.value, action.activity)
                      ? schedule.value
                      : null,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

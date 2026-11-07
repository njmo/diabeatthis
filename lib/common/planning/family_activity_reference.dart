import '../../features/activity/data/drafts/activity_draft.dart';

/// New definitions are part of the proposal; only the child allocates an ID.
Map<String, dynamic> familyActivityReference(ActivityDraft activity) =>
    activity.map(
      existing: (item) => {'activityId': item.id},
      draft: (item) {
        validateFamilyActivityDefinition(item);
        return {
          'activityId': null,
          'activity': {
            'name': item.name.trim(),
            'percentagePre': item.percentagePre,
            'percentagePost': item.percentagePost,
            'durationMinutes': item.durationMinutes,
          },
        };
      },
    );

void validateFamilyActivityDefinition(ActivityDraft activity) {
  if (activity.name.trim().length < 2 ||
      activity.name.trim().length > 30 ||
      activity.percentagePre < 1 ||
      activity.percentagePre > 99 ||
      activity.percentagePost < 1 ||
      activity.percentagePost > 99 ||
      (activity.durationMinutes != null &&
          (activity.durationMinutes! < 1 ||
              activity.durationMinutes! > 1440))) {
    throw ArgumentError('Invalid activity definition');
  }
}

ActivityDraft? familyInlineActivity(Map<String, dynamic>? values) {
  final data = values?['activity'];
  if (data is! Map) return null;
  final draft = ActivityDraft.draft(
    name: data['name'] as String,
    percentagePre: data['percentagePre'] as int,
    percentagePost: data['percentagePost'] as int,
    durationMinutes: data['durationMinutes'] as int?,
  );
  validateFamilyActivityDefinition(draft);
  return draft;
}

import '../../core/drift/database_impl.dart';
import '../../features/activity/data/drafts/activity_draft.dart';
import '../../features/activity/data/mappers/activity_draft_mapper.dart';
import '../planning/family_activity_reference.dart';

/// Called inside the plan savepoint: rejection rolls back the new definition.
Future<int> resolveFamilyActivity(DatabaseImpl db, Map values) async {
  final id = values['activityId'];
  if (id is int && values['activity'] == null) return id;
  final data = values['activity'] as Map;
  final draft = ActivityDraft.draft(
    name: data['name'] as String,
    percentagePre: data['percentagePre'] as int,
    percentagePost: data['percentagePost'] as int,
    durationMinutes: data['durationMinutes'] as int?,
  );
  validateFamilyActivityDefinition(draft);
  final activity = await db.activityDao.insertActivity(draft.toCompanion());
  if (activity == null) throw StateError('Could not create activity');
  return activity.id;
}

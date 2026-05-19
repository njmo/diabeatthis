import 'package:drift/drift.dart' as d;

import '../../../../core/drift/entity/activity.dart';
import '../drafts/activity_log_draft.dart';

extension ActivityLogDraftToCompanion on ActivityLogDraft {
  ActivityLogCompanion toCompanion({required int activityId}) {
    return ActivityLogCompanion(
      id: d.Value<int>.absent(),
      activityId: d.Value(activityId),
      startedAt: d.Value(startedAt.millisecondsSinceEpoch),
    );
  }
}

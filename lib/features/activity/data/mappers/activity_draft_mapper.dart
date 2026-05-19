import 'package:drift/drift.dart' as d;

import '../../../../core/domain/model/activity.dart' as domain;
import '../../../../core/drift/entity/activity.dart';
import '../drafts/activity_draft.dart';

extension DomainActivityDraftMapper on domain.Activity {
  ActivityDraft toDraft() {
    return ActivityDraft.existing(
      id: id,
      name: name,
      percentagePre: percentagePre,
      percentagePost: percentagePost,
      durationMinutes: durationMinutes,
    );
  }
}

extension ActivityDraftDomainMapper on ActivityDraft {
  domain.Activity toDomain() {
    return map(
      draft: (_) => throw StateError('Activity draft does not have an id'),
      existing: (activity) => domain.Activity(
        id: activity.id,
        name: activity.name,
        percentagePre: activity.percentagePre,
        percentagePost: activity.percentagePost,
        durationMinutes: activity.durationMinutes,
      ),
    );
  }
}

extension ActivityDraftToCompanion on ActivityDraft {
  ActivityCompanion toCompanion() {
    return map(
      draft: (activity) => ActivityCompanion(
        id: d.Value<int>.absent(),
        name: d.Value(activity.name),
        percentagePre: d.Value(activity.percentagePre),
        percentagePost: d.Value(activity.percentagePost),
        durationMinutes: d.Value(activity.durationMinutes),
      ),
      existing: (_) =>
          throw StateError('Existing activity draft cannot be inserted'),
    );
  }
}

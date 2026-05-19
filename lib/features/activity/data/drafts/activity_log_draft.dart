import 'package:freezed_annotation/freezed_annotation.dart';

import 'activity_draft.dart';

part 'activity_log_draft.freezed.dart';

@freezed
abstract class ActivityLogDraft with _$ActivityLogDraft {
  const factory ActivityLogDraft({
    required ActivityDraft activity,
    required DateTime startedAt,
  }) = _ActivityLogDraft;
}

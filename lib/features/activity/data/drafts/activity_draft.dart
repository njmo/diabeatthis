import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_draft.freezed.dart';

@freezed
abstract class ActivityDraft with _$ActivityDraft {
  const factory ActivityDraft.draft({
    required String name,
    required int percentagePre,
    required int percentagePost,
    required int? durationMinutes,
  }) = _ActivityDraftNew;

  const factory ActivityDraft.existing({
    required int id,
    required String name,
    required int percentagePre,
    required int percentagePost,
    required int? durationMinutes,
  }) = _ActivityDraftExisting;
}

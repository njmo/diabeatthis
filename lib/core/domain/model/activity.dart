import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class Activity with _$Activity {
  const factory Activity.existing({
    required int id,
    required String name,
    required int percentagePre,
    required int percentagePost,
  }) = _ActivityExisting;

  const factory Activity.draft({
    required String name,
    required int percentagePre,
    required int percentagePost,
  }) = _ActivityDraft;

  const factory Activity.empty() = _ActivityEmpty;
}

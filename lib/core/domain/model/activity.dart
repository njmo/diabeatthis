import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class Activity with _$Activity{
  const factory Activity.existing({
    required int id,
    required String name
  }) = _ActivityExisting;

  const factory Activity.draft({String? name}) = _ActivityDraft;
}
import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: invalid_annotation_target
part 'temporary_target_dto.freezed.dart';
part 'temporary_target_dto.g.dart';

@freezed
abstract class TemporaryTargetDto with _$TemporaryTargetDto {
  const factory TemporaryTargetDto({
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: '_id') required String nightscoutId,
    required int durationInMilliseconds,
    required int duration,
    required int targetBottom,
    required int targetTop,
  }) = _TemporaryTargetDto;

  factory TemporaryTargetDto.fromJson(Map<String, dynamic> json) =>
      _$TemporaryTargetDtoFromJson(json);
}

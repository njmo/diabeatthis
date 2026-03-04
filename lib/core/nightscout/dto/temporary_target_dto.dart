import 'package:freezed_annotation/freezed_annotation.dart';

part 'temporary_target_dto.freezed.dart';
part 'temporary_target_dto.g.dart';

@freezed
abstract class TemporaryTargetDto with _$TemporaryTargetDto {

  const factory TemporaryTargetDto({
    required String created_at,
    required int durationInMilliseconds,
    required int duration,
    required int targetBottom,
    required int targetTop,
  }) = _TemporaryTargetDto;

  factory TemporaryTargetDto.fromJson(Map<String, dynamic> json) =>
      _$TemporaryTargetDtoFromJson(json);
}
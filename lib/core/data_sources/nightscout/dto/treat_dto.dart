import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: invalid_annotation_target
part 'treat_dto.freezed.dart';
part 'treat_dto.g.dart';

@freezed
abstract class TreatDto with _$TreatDto {
  const factory TreatDto({
    @JsonKey(name: 'created_at') required String createdAt,
    required int carbs,
  }) = _TreatDto;

  factory TreatDto.fromJson(Map<String, dynamic> json) =>
      _$TreatDtoFromJson(json);
}

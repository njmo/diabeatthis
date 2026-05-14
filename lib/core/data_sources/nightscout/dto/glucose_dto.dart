import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: invalid_annotation_target
part 'glucose_dto.freezed.dart';
part 'glucose_dto.g.dart';

@freezed
abstract class GlucoseDto with _$GlucoseDto {
  const factory GlucoseDto({
    @JsonKey(name: '_id') required String id,
    @JsonKey(name: 'created_at') required String createdAt,
    required int date,
    required int sgv,
    required String direction,
  }) = _GlucoseDto;

  factory GlucoseDto.fromJson(Map<String, dynamic> json) =>
      _$GlucoseDtoFromJson(json);
}

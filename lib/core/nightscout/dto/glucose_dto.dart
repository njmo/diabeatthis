import 'package:freezed_annotation/freezed_annotation.dart';

part 'glucose_dto.freezed.dart';
part 'glucose_dto.g.dart';

@freezed
abstract class GlucoseDto with _$GlucoseDto {

  const factory GlucoseDto({
    required String created_at,
    required int sgv,
    required String direction,
  }) = _GlucoseDto;

  factory GlucoseDto.fromJson(Map<String, dynamic> json) =>
      _$GlucoseDtoFromJson(json);
}

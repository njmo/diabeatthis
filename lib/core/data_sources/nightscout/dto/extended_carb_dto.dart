import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: invalid_annotation_target
part 'extended_carb_dto.freezed.dart';
part 'extended_carb_dto.g.dart';

@freezed
abstract class ExtendedCarbDto with _$ExtendedCarbDto {
  const factory ExtendedCarbDto({
    @JsonKey(name: 'created_at') required String createdAt,
    required int carbs,
    required int duration,
  }) = _ExtendedCarbDto;

  factory ExtendedCarbDto.fromJson(Map<String, dynamic> json) =>
      _$ExtendedCarbDtoFromJson(json);
}

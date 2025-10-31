import 'package:freezed_annotation/freezed_annotation.dart';

part 'extended_carb_dto.freezed.dart';
part 'extended_carb_dto.g.dart';

@freezed
abstract class ExtendedCarbDto with _$ExtendedCarbDto {

  const factory ExtendedCarbDto({
    required String created_at,
    required int carbs,
    required int duration,
  }) = _ExtendedCarbDto;

  factory ExtendedCarbDto.fromJson(Map<String, dynamic> json) =>
      _$ExtendedCarbDtoFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'treat_dto.freezed.dart';
part 'treat_dto.g.dart';

@freezed
abstract class TreatDto with _$TreatDto {

  const factory TreatDto({
    required String created_at,
    required int carbs,
  }) = _TreatDto;

  factory TreatDto.fromJson(Map<String, dynamic> json) =>
      _$TreatDtoFromJson(json);
}

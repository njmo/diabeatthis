import 'package:freezed_annotation/freezed_annotation.dart';

part 'manual_bolus_dto.freezed.dart';
part 'manual_bolus_dto.g.dart';

@freezed
abstract class ManualBolusDto with _$ManualBolusDto {

  const factory ManualBolusDto({
    required String created_at,
    required double insulin,
  }) = _ManualBolusDto;

  factory ManualBolusDto.fromJson(Map<String, dynamic> json) =>
      _$ManualBolusDtoFromJson(json);
}

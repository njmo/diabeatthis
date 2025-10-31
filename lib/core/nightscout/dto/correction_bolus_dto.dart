import 'package:freezed_annotation/freezed_annotation.dart';

part 'correction_bolus_dto.freezed.dart';
part 'correction_bolus_dto.g.dart';

@freezed
abstract class CorrectionBolusDto with _$CorrectionBolusDto {

  const factory CorrectionBolusDto({
    required String created_at,
    required double insulin,
  }) = _CorrectionBolusDto;

  factory CorrectionBolusDto.fromJson(Map<String, dynamic> json) =>
      _$CorrectionBolusDtoFromJson(json);
}

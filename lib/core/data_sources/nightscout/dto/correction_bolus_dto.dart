import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: invalid_annotation_target
part 'correction_bolus_dto.freezed.dart';
part 'correction_bolus_dto.g.dart';

@freezed
abstract class CorrectionBolusDto with _$CorrectionBolusDto {
  const factory CorrectionBolusDto({
    @JsonKey(name: 'created_at') required String createdAt,
    required double insulin,
  }) = _CorrectionBolusDto;

  factory CorrectionBolusDto.fromJson(Map<String, dynamic> json) =>
      _$CorrectionBolusDtoFromJson(json);
}

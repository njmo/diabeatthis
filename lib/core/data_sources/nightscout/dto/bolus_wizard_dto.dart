import 'dart:convert';
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bolus_wizard_dto.freezed.dart';
part 'bolus_wizard_dto.g.dart';

@freezed
abstract class BolusWizardDto with _$BolusWizardDto {
  const factory BolusWizardDto({
    required String id,
    @JsonKey(name: 'created_at') required String createdAt,
    int? date,
    required int glucose,
    String? units,
    String? notes,
    int? mills,
    Map<String, dynamic>? bolusCalculatorResult,
  }) = _BolusWizardDto;

  factory BolusWizardDto.fromJson(Map<String, dynamic> json) => BolusWizardDto(
    id: json['_id'],
    createdAt: json['created_at'],
    date: (json['date'] as num?)?.toInt(),
    glucose: (json['glucose'] as num).toInt(),
    units: json['units'] as String?,
    notes: json['notes'] as String?,
    mills: (json['mills'] as num?)?.toInt(),
    bolusCalculatorResult: _decodeBolusCalculatorResult(
      json['bolusCalculatorResult'],
    ),
  );
}

Map<String, dynamic>? _decodeBolusCalculatorResult(Object? raw) {
  return switch (raw) {
    null => null,
    final String value => jsonDecode(value) as Map<String, dynamic>,
    final Map<String, dynamic> value => value,
    _ => null,
  };
}

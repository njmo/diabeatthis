import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal_dto.freezed.dart';
part 'meal_dto.g.dart';

@freezed
abstract class MealDto with _$MealDto {
  const factory MealDto({
    required String id,
    required String created_at,
    required int glucose,
    Map<String, dynamic>? bolusCalculatorResult,
  }) = _MealDto;

  factory MealDto.fromJson(Map<String, dynamic> json) => MealDto(
    id: json['_id'],
    created_at: json['created_at'],
    glucose: (json['glucose'] as num).toInt(),
    bolusCalculatorResult: jsonDecode(json['bolusCalculatorResult']),
  );
}

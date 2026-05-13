import 'dart:convert';
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal_dto.freezed.dart';
part 'meal_dto.g.dart';

@freezed
abstract class MealDto with _$MealDto {
  const factory MealDto({
    required String id,
    @JsonKey(name: 'created_at') required String createdAt,
    required int glucose,
    Map<String, dynamic>? bolusCalculatorResult,
  }) = _MealDto;

  factory MealDto.fromJson(Map<String, dynamic> json) => MealDto(
    id: json['_id'],
    createdAt: json['created_at'],
    glucose: (json['glucose'] as num).toInt(),
    bolusCalculatorResult: jsonDecode(json['bolusCalculatorResult']),
  );
}

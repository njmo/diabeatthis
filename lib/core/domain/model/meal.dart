import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal.freezed.dart';

@freezed
abstract class Meal with _$Meal {
  const Meal._();

  const factory Meal({
    required int id,
    required String name,
    int? glucose,
    int? carbs,
    double? insulin,
    String? nightscoutObjectId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? plannedAt,
    DateTime? eatenAt,
    String? status,
    String? notes,
    int? mealTemplateId,
  }) = _Meal;

  String getParts() =>
      "🍽️ ${carbs?.toStringAsFixed(2) ?? 0}g \n 💉${insulin?.toStringAsFixed(2)}U";

  IconData getIcon() => Icons.dinner_dining;

  Color getColor() => Colors.orange;
}

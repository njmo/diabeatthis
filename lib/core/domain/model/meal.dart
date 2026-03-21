import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'meal.freezed.dart';

@freezed
abstract class Meal with _$Meal implements Treatment {
  const Meal._();

  const factory Meal({
    required int id,
    required String name,
    int? glucose,
    int? carbs,
    double? insulin,
    String? nightscoutObjectId,
    DateTime? dateHappened,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? plannedAt,
    DateTime? eatenAt,
    String? status,
    String? notes,
    int? mealTemplateId,
  }) = _Meal;

  @override
  String getParts() => "🍽️ ${carbs?.toStringAsFixed(2) ?? 0}g \n 💉${insulin?.toStringAsFixed(2)}U";

  @override
  IconData getIcon() => Icons.dinner_dining;

  @override
  Color getColor() => Colors.orange;
}
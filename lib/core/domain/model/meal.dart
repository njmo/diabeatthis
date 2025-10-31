import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'meal.freezed.dart';

@freezed
abstract class Meal with _$Meal implements Treatment {
  const Meal._();

  const factory Meal({
    required int id,
    required int glucose,
    required int carbs,
    required double insulin,
    String? nightscoutObjectId,
    DateTime? dateHappened,
    DateTime? createdAt,
    DateTime? plannedAt,
    DateTime? eatenAt,
    String? status,
  }) = _Meal;

  @override
  String getParts() => "🍽️ ${carbs}g \n 💉${insulin.toStringAsFixed(2)}U";

  @override
  IconData getIcon() => Icons.dinner_dining;

  @override
  Color getColor() => Colors.orange;
}
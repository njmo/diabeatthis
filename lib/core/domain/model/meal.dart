import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal.freezed.dart';

@JsonEnum(valueField: 'storageValue')
enum MealPurpose {
  meal('meal'),
  lowTreatment('lowTreatment');

  const MealPurpose(this.storageValue);

  final String storageValue;

  static MealPurpose fromStorage(String? value) {
    return MealPurpose.values.firstWhere(
      (purpose) => purpose.storageValue == value,
      orElse: () => MealPurpose.meal,
    );
  }
}

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
    @Default(MealPurpose.meal) MealPurpose purpose,
    String? status,
    String? notes,
    int? mealTemplateId,
  }) = _Meal;

  String getParts() =>
      "🍽️ ${carbs?.toStringAsFixed(2) ?? 0}g \n 💉${insulin?.toStringAsFixed(2)}U";

  IconData getIcon() => Icons.dinner_dining;

  Color getColor() => Colors.orange;
}

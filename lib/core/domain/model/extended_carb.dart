import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'extended_carb.freezed.dart';

@freezed
abstract class ExtendedCarb with _$ExtendedCarb implements Treatment {
  const ExtendedCarb._();

  const factory ExtendedCarb({
    required String? externalId,
    required DateTime createdAt,
    required int carbs,
    required int duration,
    @Default(true) bool isValid,
  }) = _ExtendedCarb;

  /*

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'carbs': carbs,
      'duration': duration,
    };
  }

  factory ExtendedCarb.fromJson(Map<String, dynamic> json) => ExtendedCarb(
    date: DateTime.parse(json['created_at']),
    carbs: (json['carbs'] as num).toInt(),
    duration: (json['duration'] as num).toInt(),
  );

   */

  @override
  String getParts() => "🍖 ${carbs}g \n dur: ${duration / 60000}min";

  @override
  IconData getIcon() => Icons.restaurant;

  @override
  Color getColor() => Colors.deepPurpleAccent;
}

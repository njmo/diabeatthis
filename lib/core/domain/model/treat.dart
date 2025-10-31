import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'treat.freezed.dart';

@freezed
abstract class Treat with _$Treat implements Treatment {
  const Treat._();

  const factory Treat({
    required int id,
    required DateTime dateHappened,
    required int carbs,
  }) = _Treat;

  /*

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'carbs': carbs,
    };
  }

  factory Treat.fromJson(Map<String, dynamic> json) => Treat(
    date: DateTime.parse(json['created_at']),
    carbs: json['carbs'],
  );
   */

  @override
  String getParts() => "🍽️ ${carbs}g";

  @override
  IconData getIcon() => Icons.bakery_dining;

  @override
  Color getColor() => Colors.green;
}
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'treat.freezed.dart';

@freezed
abstract class Treat with _$Treat implements Treatment {
  const Treat._();

  const factory Treat({
    required int id,
    required DateTime createdAt,
    required int carbs,
  }) = _Treat;

  @override
  String getParts() => "🍽️ ${carbs}g";

  @override
  IconData getIcon() => Icons.bakery_dining;

  @override
  Color getColor() => Colors.green;
}
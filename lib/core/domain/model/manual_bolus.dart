import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'manual_bolus.freezed.dart';

@freezed
abstract class ManualBolus with _$ManualBolus implements Treatment {
  const ManualBolus._();

  const factory ManualBolus({
    required int id,
    required DateTime createdAt,
    required double insulin,
  }) = _ManualBolus;
  /*

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'insulin': insulin,
    };
  }

  factory ManualBolus.fromJson(Map<String, dynamic> json) => ManualBolus(
    date: DateTime.parse(json['created_at']),
    insulin: (json['insulin'] as num).toDouble(),
  );
 */

  @override
  String getParts() => "💉${insulin.toStringAsFixed(2)}U";

  @override
  IconData getIcon() => Icons.man;

  @override
  Color getColor() => Colors.black;
}

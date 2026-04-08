import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'treatment_base.dart';

part 'correction_bolus.freezed.dart';

@freezed
abstract class CorrectionBolus with _$CorrectionBolus implements Treatment {
  const CorrectionBolus._();

  const factory CorrectionBolus({
    required int id,
    required DateTime createdAt,
    required double insulin
  }) = _CorrectionBolus;

@override
String getParts() => "💉${insulin.toStringAsFixed(2)}U";

@override
IconData getIcon() => Icons.vaccines;

@override
Color getColor() => Colors.blue;
}
/*

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'insulin': insulin,
    };
  }

  factory BolusCorrection.fromJson(Map<String, dynamic> json) => BolusCorrection(
    date: DateTime.parse(json['created_at']),
    insulin: (json['insulin'] as num).toDouble(),
  );
*/
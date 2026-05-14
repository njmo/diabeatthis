import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'bolus_calculator_result.dart';
import 'treatment_base.dart';

part 'bolus_wizard.freezed.dart';

@freezed
abstract class BolusWizard with _$BolusWizard implements Treatment {
  const BolusWizard._();

  const factory BolusWizard({
    required int id,
    required String? nightscoutObjectId,
    required DateTime createdAt,
    required DateTime? date,
    required int glucose,
    required String? units,
    required String? notes,
    required BolusCalculatorResult? calculatorResult,
  }) = _BolusWizard;

  double get carbs => calculatorResult?.carbs ?? 0;

  double get insulin => calculatorResult?.totalInsulin ?? 0;

  @override
  String getParts() =>
      "🍽️ ${carbs.toStringAsFixed(2)}g \n 💉${insulin.toStringAsFixed(2)}U";

  @override
  IconData getIcon() => Icons.calculate;

  @override
  Color getColor() => Colors.deepOrange;
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'bolus_calculator_result.freezed.dart';

@freezed
abstract class BolusCalculatorResult with _$BolusCalculatorResult {
  const factory BolusCalculatorResult({
    required double? basalIob,
    required double? bolusIob,
    required double? carbs,
    required double? carbsInsulin,
    required double? cob,
    required double? cobInsulin,
    required DateTime? dateCreated,
    required double? glucoseDifference,
    required double? glucoseInsulin,
    required double? glucoseTrend,
    required double? glucoseValue,
    required double? ic,
    required int? id,
    required double? isf,
    required String? note,
    required double? otherCorrection,
    required int? percentageCorrection,
    required String? profileName,
    required double? superbolusInsulin,
    required double? targetBGHigh,
    required double? targetBGLow,
    required DateTime? timestamp,
    required double? totalInsulin,
    required double? trendInsulin,
    required int? utcOffset,
    required int? version,
    required bool? wasBasalIOBUsed,
    required bool? wasBolusIOBUsed,
    required bool? wasCOBUsed,
    required bool? wasGlucoseUsed,
    required bool? wasSuperbolusUsed,
    required bool? wasTempTargetUsed,
    required bool? wasTrendUsed,
    required bool? wereCarbsUsed,
  }) = _BolusCalculatorResult;
}

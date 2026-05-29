import 'package:freezed_annotation/freezed_annotation.dart';

part 'low_treatment_related_record.freezed.dart';

@freezed
abstract class LowTreatmentRelatedRecord with _$LowTreatmentRelatedRecord {
  const factory LowTreatmentRelatedRecord.meal({
    required int id,
    required String name,
  }) = LowTreatmentRelatedMealRecord;

  const factory LowTreatmentRelatedRecord.activity({
    required int id,
    required String name,
  }) = LowTreatmentRelatedActivityRecord;
}
